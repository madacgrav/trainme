# Implementation Plan

## Overview
Harden TrainMe's persistence, import, calendar, and notification paths so they fail loudly
and recoverably; add the packaging and CI scaffolding the project lacks; cover each fixed
path with tests. Closes BACKLOG rows 20–27 (issues #22–#29).

**Test command (every phase):**
```bash
xcodegen generate && xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' test
```
If `xcodebuild` says it requires Xcode, prefix with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
Commit after each phase with message `Phase N: <name>`.

**Conventions to keep:** Swift 6 strict concurrency. Swift Testing (`@Test`, `#expect`,
`#require`), free functions, `@MainActor` on view-model tests. Protocol-per-service with
default-argument injection. `save() async -> Bool` + `errorMessage: String?` on forms.

---

## Phase 1: Scaffolding — CI, manifests, logger (#27)

### Changes

#### 1. Logger
**File**: `Sources/Support/Log.swift` — **create**
```swift
import OSLog

/// One logger per subsystem area. There was previously no logging at all.
enum Log {
    private static let subsystem = "com.madacgrav.trainme"
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let archive = Logger(subsystem: subsystem, category: "archive")
    static let calendar = Logger(subsystem: subsystem, category: "calendar")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
```

#### 2. Privacy manifest
**File**: `Sources/PrivacyInfo.xcprivacy` — **create**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

#### 3. Entitlements
**File**: `Sources/TrainMe.entitlements` — **create**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

#### 4. Project wiring
**File**: `project.yml` — **modify**. Under `targets.TrainMe.settings.base` add:
```yaml
        CODE_SIGN_ENTITLEMENTS: Sources/TrainMe.entitlements
```
XcodeGen picks up `.xcprivacy` under `sources: [Sources]` as a resource and excludes
`.entitlements` from build phases. Verify with the bundle check below; if the manifest is
missing from the built app, add an explicit entry:
```yaml
    sources:
      - Sources
      - path: Sources/PrivacyInfo.xcprivacy
        buildPhase: resources
```

#### 5. CI workflow
**File**: `.github/workflows/ci.yml` — **create**
```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    runs-on: macos-26
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode 26
        run: |
          sudo xcode-select -s /Applications/Xcode_26.app/Contents/Developer || sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
          xcodebuild -version
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate project
        run: xcodegen generate
      - name: List simulators
        run: xcrun simctl list devices available | grep -i iphone
      - name: Test
        run: |
          xcodebuild -scheme TrainMe \
            -destination 'platform=iOS Simulator,name=iPhone 17' \
            CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= \
            test
```
If `macos-26` is not available, switch to `runs-on: macos-15` and add
`maxim-lobanov/setup-xcode@v1` with `xcode-version: '26'` before the Xcode step. If the
"List simulators" step shows no `iPhone 17`, change the destination to a listed name.

#### 6. README
**File**: `README.md` — **modify**. Under the title add a badge line:
```markdown
![CI](https://github.com/madacgrav/trainme/actions/workflows/ci.yml/badge.svg)
```
In "Project layout" add: `` `Sources/Support/` — shared helpers (logging, formatters) ``.

### Verification
#### Automated
- [x] Test command passes locally
- [x] `xcodebuild -scheme TrainMe -showBuildSettings 2>/dev/null | grep CODE_SIGN_ENTITLEMENTS` prints `Sources/TrainMe.entitlements`
- [x] After a simulator build: `find build -name PrivacyInfo.xcprivacy -path '*TrainMe.app*' | head -1` returns a path (or use the DerivedData path xcodebuild prints)
- [x] `grep -c "Logger(" Sources/Support/Log.swift` → 5
#### Manual
- [ ] Push the branch and open a PR; the CI check appears and goes green

---

## Phase 2: Versioned schema and schema-keyed backup (#22)

### Changes

#### 1. SchemaV1 and migration plan
**File**: `Sources/Persistence/SchemaV1.swift` — **create**
```swift
import SwiftData

/// First versioned schema. Mirrors the models exactly as shipped in 1.0; the
/// model classes live in Sources/Models and are referenced, not nested, so no
/// call site changes. A future change adds SchemaV2 + one MigrationStage.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Client.self, Exercise.self, Workout.self, WorkoutEntry.self,
         Session.self, WorkoutInstance.self, PlannedEntry.self, SetRecord.self]
    }
    /// Stable string for StoreBackup's defaults key ("1.0.0").
    static var versionString: String {
        let v = versionIdentifier
        return "\(v.major).\(v.minor).\(v.patch)"
    }
}

enum TrainMeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
```

#### 2. Container uses the plan
**File**: `Sources/Persistence/PersistenceController.swift` — **modify**
```swift
enum PersistenceController {
    /// Kept for callers/tests that enumerate the model types.
    static var schemaTypes: [any PersistentModel.Type] { SchemaV1.models }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory {
            do {
                try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            } catch {
                Log.persistence.error("createDirectory failed: \(error.localizedDescription)")
            }
        }
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: TrainMeMigrationPlan.self,
            configurations: config
        )
    }
}
```

#### 3. StoreBackup keyed on schema version
**File**: `Sources/Persistence/StoreBackup.swift` — **modify**
- `static let versionKey = "lastRunSchemaVersion"`; add `static let legacyVersionKey = "lastRunAppVersion"`.
- Backup dir name → `"pre-schema-\(currentVersion)"`.
- Replace the body of `backupIfVersionChanged` start with:
```swift
        var lastVersion = defaults.string(forKey: versionKey)
        if lastVersion == nil, defaults.string(forKey: legacyVersionKey) != nil {
            // Upgrading from the pre-versioned-schema build: the store exists but
            // its schema version is unknown. Take one backup, then drop the old key.
            lastVersion = "legacy"
            defaults.removeObject(forKey: legacyVersionKey)
        }
        if let lastVersion, lastVersion != currentVersion {
            ... (existing copy logic, dir "pre-schema-\(currentVersion)")
        }
        defaults.set(currentVersion, forKey: versionKey)
```
Keep "record only after successful copy" ordering. Note: `removeObject(forKey: legacyVersionKey)`
happens before the copy; if the copy throws, the next launch has neither key and skips the
backup. To keep retry semantics, move the `removeObject` to after the copy loop (just before
`defaults.set`). Do that.
- Update doc comments: "schema version" not "app version".

#### 4. Bootstrap passes schema version and cleans snapshot leftovers
**File**: `Sources/TrainMeApp.swift` — **modify** `AppBootstrap.init`:
```swift
    init() {
        do {
            try StoreBackup.backupIfVersionChanged(storeURL: Self.storeURL, currentVersion: SchemaV1.versionString)
        } catch {
            Log.persistence.error("Pre-open backup failed: \(error.localizedDescription)")
        }
        state = Self.attempt()
    }
```
(Phase 3 adds snapshot cleanup here.) Also log in `restoreBackupAndRetry` and
`resetStoreAndRetry` catch paths instead of `try?` (keep behavior identical).

#### 5. Tests
**File**: `Tests/StoreBackupTests.swift` — **modify**: all `"Backups/pre-1.1/..."` paths →
`"Backups/pre-schema-1.1/..."`. **Add**:
```swift
@Test func legacyAppVersionKeyTriggersOneBackupThenMigratesKey() throws {
    let fm = FileManager.default
    let dir = try makeStoreDir(); defer { try? fm.removeItem(at: dir) }
    let storeURL = dir.appending(path: "default.store")
    try Data("old".utf8).write(to: storeURL)
    let defaults = UserDefaults(suiteName: "StoreBackupTests-\(UUID().uuidString)")!
    defaults.set("1.0", forKey: StoreBackup.legacyVersionKey)

    try StoreBackup.backupIfVersionChanged(storeURL: storeURL, currentVersion: "1.0.0", defaults: defaults)
    #expect(fm.fileExists(atPath: dir.appending(path: "Backups/pre-schema-1.0.0/default.store").path))
    #expect(defaults.string(forKey: StoreBackup.legacyVersionKey) == nil)
    #expect(defaults.string(forKey: StoreBackup.versionKey) == "1.0.0")

    // Second launch on the same schema: no new backup directory.
    try fm.removeItem(at: dir.appending(path: "Backups"))
    try StoreBackup.backupIfVersionChanged(storeURL: storeURL, currentVersion: "1.0.0", defaults: defaults)
    #expect(!fm.fileExists(atPath: dir.appending(path: "Backups").path))
}
```
**File**: `Tests/SchemaTests.swift` — **create**
```swift
import SwiftData
import Testing
@testable import TrainMe

@Test func schemaV1ListsAllModels() {
    #expect(SchemaV1.models.count == 8)
    #expect(SchemaV1.versionString == "1.0.0")
    #expect(TrainMeMigrationPlan.schemas.count == 1)
    #expect(TrainMeMigrationPlan.stages.isEmpty)
}

@Test func containerOpensThroughMigrationPlan() throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    #expect(container.schema.entities.count == 8)
}
```

### Verification
#### Automated
- [x] Test command passes (all existing + 3 new tests)
- [x] `grep -rn "lastRunAppVersion" Sources` → only the `legacyVersionKey` declaration
- [x] `grep -rn "try?" Sources/TrainMeApp.swift Sources/Persistence/PersistenceController.swift` → none
#### Manual
- [ ] Export data from the current build on madphone (Settings → Export). Install this build
  over it (see memory note for device build command). Launch: data intact, Settings shows
  same clients/sessions. On a Mac, `xcrun devicectl` or Xcode's container download should
  show `Application Support/Backups/pre-schema-1.0.0/` exists (one-time legacy backup).
- [ ] Relaunch: no new backup directory, no RecoveryView.

---

## Phase 3: Safe replace-import with snapshot and rollback (#23, #29)

### Changes

#### 1. Rollback inside the actor and a decode error case
**File**: `Sources/Services/Archive/DataArchive.swift` — **modify**
```swift
enum ArchiveError: Error, Equatable {
    case newerThanApp(Int)
    case unreadable
    /// Probe succeeded but the full envelope did not decode.
    case decodeFailed
}
```
In `importData`, replace lines 79–85 with:
```swift
        let envelope: CurrentArchive
        do {
            envelope = try decoder.decode(CurrentArchive.self, from: data)
        } catch {
            Log.archive.error("Envelope decode failed: \(error.localizedDescription)")
            throw ArchiveError.decodeFailed
        }
        do {
            if mode == .replace { try deleteAll() }
            try upsertAll(envelope)
            try modelContext.save()
        } catch {
            // Discard anything staged on this context so a later import does
            // not drag half-applied changes along with it.
            modelContext.rollback()
            Log.archive.error("Import (\(String(describing: mode))) failed, rolled back: \(error.localizedDescription)")
            throw error
        }
```
In `importArchive`, log before throwing `.unreadable`. Export failures are logged by the
caller (SettingsView) — no change to `export()`.

#### 2. SafeImporter
**File**: `Sources/Services/Archive/SafeImporter.swift` — **create**
```swift
import Foundation

/// Outcome of a guarded replace-import that did not succeed cleanly.
enum ImportOutcome: Error {
    /// The import threw; the pre-import snapshot was re-imported successfully.
    case failedAndRestored(underlying: any Error)
    /// The import threw AND restoring the snapshot threw. Data may be partial.
    case failedAndRestoreFailed(underlying: any Error, restore: any Error)
}

/// Wraps a replace-import in export → import → (on failure) restore. The
/// snapshot is a normal archive, so restore reuses the tested import path.
struct SafeImporter: Sendable {
    let archive: any DataArchiving
    let snapshotURL: URL

    static let defaultSnapshotURL = URL.applicationSupportDirectory.appending(path: "pre-import.json")

    init(archive: any DataArchiving, snapshotURL: URL = SafeImporter.defaultSnapshotURL) {
        self.archive = archive
        self.snapshotURL = snapshotURL
    }

    func importReplacing(url: URL) async throws {
        let fm = FileManager.default
        let exported = try await archive.export()
        try? fm.removeItem(at: snapshotURL)
        try fm.moveItem(at: exported, to: snapshotURL)
        try (try Data(contentsOf: snapshotURL)).write(to: snapshotURL, options: [.atomic, .completeFileProtection])
        defer { Self.removeSnapshot(at: snapshotURL) }

        do {
            try await archive.importArchive(url: url, mode: .replace)
        } catch {
            Log.archive.error("Replace-import failed, restoring snapshot: \(error.localizedDescription)")
            do {
                let snapshot = try Data(contentsOf: snapshotURL)
                try await archive.importData(snapshot, mode: .replace)
                throw ImportOutcome.failedAndRestored(underlying: error)
            } catch let outcome as ImportOutcome {
                throw outcome
            } catch let restoreError {
                Log.archive.fault("Snapshot restore failed: \(restoreError.localizedDescription)")
                throw ImportOutcome.failedAndRestoreFailed(underlying: error, restore: restoreError)
            }
        }
    }

    /// Call at launch too, in case the app died mid-import.
    static func removeSnapshot(at url: URL = defaultSnapshotURL) {
        try? FileManager.default.removeItem(at: url)
    }
}
```
Note: the `defer` removes the snapshot on both success and after a completed restore. On
`failedAndRestoreFailed` the snapshot is also removed by `defer`; to keep it for manual
recovery, move the `defer` into the success path instead: remove the snapshot only after
`importArchive` returns normally or `.failedAndRestored` is thrown. Implement it that way.

**File**: `Sources/TrainMeApp.swift` — **modify** `AppBootstrap.init`: add
`SafeImporter.removeSnapshot()` as the first line.

#### 3. SettingsView uses it and shows distinct messages
**File**: `Sources/Features/Settings/SettingsView.swift` — **modify**
Export button:
```swift
                        Task {
                            do {
                                exportURL = try await archive.export()
                                showingExporter = true
                            } catch {
                                Log.archive.error("Export failed: \(error.localizedDescription)")
                                statusMessage = "Export failed. Please try again."
                            }
                        }
```
`fileExporter` completion: add `else if case .failure(let error) = result { statusMessage = "Export wasn't saved."; Log.archive.error(...) }`.
`fileImporter` completion: add a `.failure` branch setting `statusMessage = "Couldn't open that file."`.
`runImport`:
```swift
    private func runImport(mode: ImportMode) async {
        guard let url = pendingImportURL else { return }
        defer { pendingImportURL = nil }
        do {
            switch mode {
            case .merge: try await archive.importArchive(url: url, mode: .merge)
            case .replace: try await SafeImporter(archive: archive).importReplacing(url: url)
            }
            statusMessage = "Import complete."
        } catch ArchiveError.newerThanApp {
            statusMessage = "This file was exported by a newer version of TrainMe. Update the app first."
        } catch ArchiveError.unreadable {
            statusMessage = "Import failed: the file couldn't be read."
        } catch ArchiveError.decodeFailed {
            statusMessage = "Import failed: the file isn't a valid TrainMe export."
        } catch ImportOutcome.failedAndRestored {
            statusMessage = "Import failed. Your previous data was restored."
        } catch ImportOutcome.failedAndRestoreFailed {
            statusMessage = "Import failed and your data may be incomplete. Re-import your last export now."
        } catch {
            Log.archive.error("Import failed: \(error.localizedDescription)")
            statusMessage = "Import failed. Please try again."
        }
    }
```

#### 4. Tests
**File**: `Tests/SafeImporterTests.swift` — **create**
```swift
import Foundation
import SwiftData
import Testing
@testable import TrainMe

/// Delegates to a real actor but fails importArchive(url:) on demand.
actor FlakyArchive: DataArchiving {
    let inner: DataArchiveActor
    var failImportArchive = false
    init(inner: DataArchiveActor) { self.inner = inner }
    func setFail(_ v: Bool) { failImportArchive = v }
    func export() async throws -> URL { try await inner.export() }
    func importArchive(url: URL, mode: ImportMode) async throws {
        if failImportArchive { throw ArchiveError.unreadable }
        try await inner.importArchive(url: url, mode: mode)
    }
    func importData(_ data: Data, mode: ImportMode) async throws { try await inner.importData(data, mode: mode) }
}

private func tmpURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory.appending(path: "safe-import-\(UUID().uuidString)-\(name)")
}

@Test func failedReplaceImportRestoresSnapshot() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let clients = SwiftDataClientRepository(modelContainer: container)
    let real = DataArchiveActor(modelContainer: container)
    try await clients.upsert(ClientDTO(id: UUID(), name: "Keep Me", phoneE164: "", goal: nil, injuries: nil, notes: nil, isArchived: false, createdAt: .now, updatedAt: .now))
    let flaky = FlakyArchive(inner: real)
    await flaky.setFail(true)
    let sut = SafeImporter(archive: flaky, snapshotURL: tmpURL("snap.json"))

    await #expect(throws: ImportOutcome.self) {
        try await sut.importReplacing(url: tmpURL("ignored.json"))
    }
    let names = try await clients.all().map(\.name)
    #expect(names == ["Keep Me"])
    #expect(!FileManager.default.fileExists(atPath: sut.snapshotURL.path))
}

@Test func replaceImportIntoNonEmptyStoreRemovesLocalRows() async throws {
    // Source store with one client → export; target store with a different client → replace.
    let src = try PersistenceController.makeContainer(inMemory: true)
    let srcClients = SwiftDataClientRepository(modelContainer: src)
    try await srcClients.upsert(ClientDTO(id: UUID(), name: "From Archive", phoneE164: "", goal: nil, injuries: nil, notes: nil, isArchived: false, createdAt: .now, updatedAt: .now))
    let exportURL = try await DataArchiveActor(modelContainer: src).export()
    let archiveFile = tmpURL("archive.json")
    try FileManager.default.copyItem(at: exportURL, to: archiveFile)

    let dst = try PersistenceController.makeContainer(inMemory: true)
    let dstClients = SwiftDataClientRepository(modelContainer: dst)
    try await dstClients.upsert(ClientDTO(id: UUID(), name: "Local Only", phoneE164: "", goal: nil, injuries: nil, notes: nil, isArchived: false, createdAt: .now, updatedAt: .now))
    try await SafeImporter(archive: DataArchiveActor(modelContainer: dst), snapshotURL: tmpURL("snap.json")).importReplacing(url: archiveFile)
    #expect(try await dstClients.all().map(\.name) == ["From Archive"])
}

@Test func importArchiveMissingFileIsUnreadable() async throws {
    let archive = DataArchiveActor(modelContainer: try PersistenceController.makeContainer(inMemory: true))
    await #expect(throws: ArchiveError.unreadable) {
        try await archive.importArchive(url: tmpURL("does-not-exist.json"), mode: .merge)
    }
}

@Test func validProbeMalformedBodyIsDecodeFailed() async throws {
    let archive = DataArchiveActor(modelContainer: try PersistenceController.makeContainer(inMemory: true))
    let data = Data(#"{"schemaVersion":1,"exportedAt":"not-a-date"}"#.utf8)
    await #expect(throws: ArchiveError.decodeFailed) {
        try await archive.importData(data, mode: .merge)
    }
}
```
Adjust `ClientDTO` initializer arguments to match `Sources/Models/DTO/ClientDTO.swift` if the
memberwise order differs.

### Verification
#### Automated
- [ ] Test command passes (4 new tests)
- [ ] `grep -n "rollback()" Sources/Services/Archive/DataArchive.swift` → 1 hit
- [ ] `grep -n "try? await archive" Sources/Features/Settings/SettingsView.swift` → none
#### Manual
- [ ] On device: export, then edit the export file to truncate it mid-array, import in
  Replace mode → message "Import failed. Your previous data was restored." and all data
  still present.
- [ ] Import a valid export in Replace mode → "Import complete."; `pre-import.json` absent
  afterwards (check via Xcode container download or trust the test).

---

## Phase 4: Notification authorization gate and Permissions row (#25)

### Changes

#### 1. Protocol and service
**File**: `Sources/Services/NotificationService.swift` — **modify**
```swift
protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    /// Replaces all pending session alerts with the nearest-N set. No-ops the
    /// add step unless authorized or provisional.
    func reschedule(upcoming: [(id: UUID, startAt: Date, clientName: String)]) async
}

final class LocalNotificationService: NotificationScheduling {
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Log.notifications.error("requestAuthorization failed: \(error.localizedDescription)")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func reschedule(upcoming: ...) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: sessionAlertIdentifiers(from: pending))

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            Log.notifications.info("Skipping \(upcoming.count) session alerts: status \(status.rawValue)")
            return
        }
        for alert in selectAlerts(sessions: upcoming, now: .now) {
            ... (unchanged content/trigger)
            do {
                try await center.add(UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger))
            } catch {
                Log.notifications.error("add \(alert.identifier) failed: \(error.localizedDescription)")
            }
        }
    }
}
```

#### 2. Coordinator exposes status
**File**: `Sources/Services/ReminderCoordinator.swift` — **modify**
- `import UserNotifications`.
- Add `var notificationStatus: UNAuthorizationStatus = .notDetermined`.
- `requestAuthorization()`:
```swift
    func requestAuthorization() async {
        let granted = await notifications.requestAuthorization()
        notificationStatus = await notifications.authorizationStatus()
        Log.notifications.info("Notification authorization granted=\(granted) status=\(self.notificationStatus.rawValue)")
    }
    func refreshPermissionStatus() async {
        notificationStatus = await notifications.authorizationStatus()
    }
```
- In `refresh()`: replace the two `try?` with `do/catch` that logs via `Log.notifications`
  and falls back to `[]`; call `await refreshPermissionStatus()` at the end.

#### 3. Settings Permissions section
**File**: `Sources/Features/Settings/SettingsView.swift` — **modify**
- `let reminders: ReminderCoordinator` added as second stored property; `init(archive:reminders:)`
  is the memberwise one (struct) — just add the property.
- New section after Backup:
```swift
                Section {
                    PermissionRow(title: "Notifications", status: notificationStatusText, isDenied: reminders.notificationStatus == .denied)
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("Session reminders fire 24 hours and 1 hour before each session.")
                }
```
- Helper and row view (same file, below `SettingsView`):
```swift
    private var notificationStatusText: String {
        switch reminders.notificationStatus {
        case .authorized, .provisional, .ephemeral: "Allowed"
        case .denied: "Denied"
        case .notDetermined: "Not asked yet"
        @unknown default: "Unknown"
        }
    }

struct PermissionRow: View {
    let title: String
    let status: String
    let isDenied: Bool
    var body: some View {
        HStack {
            LabeledContent(title, value: status)
            if isDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url).font(.footnote)
            }
        }
    }
}
```
- `.task { await reminders.refreshPermissionStatus() }` on the `Form`, and
  `.onChange(of: scenePhase)` (add `@Environment(\.scenePhase)`) → refresh when `.active`
  so returning from the system Settings app updates the row.

**File**: `Sources/RootView.swift` — **modify** line 59:
`SettingsView(archive: DataArchiveActor(modelContainer: container), reminders: reminders)`.

#### 4. Tests
**File**: `Tests/ReminderCoordinatorTests.swift` — **modify** `FakeNotifications`:
```swift
actor FakeNotifications: NotificationScheduling {
    private(set) var rescheduleCalls: [[UUID]] = []
    var status: UNAuthorizationStatus = .authorized
    func setStatus(_ s: UNAuthorizationStatus) { status = s }
    func requestAuthorization() async -> Bool { status == .authorized }
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func reschedule(upcoming: ...) async { rescheduleCalls.append(upcoming.map(\.id)) }
}
```
Add `import UserNotifications`. Add test:
```swift
@MainActor
@Test func refreshPublishesNotificationStatus() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let fake = FakeNotifications()
    await fake.setStatus(.denied)
    let sut = ReminderCoordinator(
        sessionRepo: SwiftDataSessionRepository(modelContainer: container),
        clientRepo: SwiftDataClientRepository(modelContainer: container),
        notifications: fake)
    await sut.refresh()
    #expect(sut.notificationStatus == .denied)
}
```
**File**: `Tests/NotificationServiceTests.swift` — **create**. The gate lives inside
`LocalNotificationService.reschedule`, which touches the real center. Extract the decision
into a pure function in `NotificationService.swift`:
```swift
/// Whether alerts may be added for this status. Pure so it is unit-testable.
func canScheduleAlerts(_ status: UNAuthorizationStatus) -> Bool {
    status == .authorized || status == .provisional
}
```
and use it in the guard. Tests:
```swift
import UserNotifications
import Testing
@testable import TrainMe

@Test func onlyAuthorizedOrProvisionalCanSchedule() {
    #expect(canScheduleAlerts(.authorized))
    #expect(canScheduleAlerts(.provisional))
    #expect(!canScheduleAlerts(.denied))
    #expect(!canScheduleAlerts(.notDetermined))
    #expect(!canScheduleAlerts(.ephemeral))
}
```

### Verification
#### Automated
- [ ] Test command passes (2 new tests)
- [ ] `grep -n "try?" Sources/Services/NotificationService.swift Sources/Services/ReminderCoordinator.swift` → none
#### Manual
- [ ] Fresh install on device → system prompt appears; tap Don't Allow → Settings tab
  Permissions shows "Denied" with "Open Settings"; tap it → system Settings opens; allow →
  return to app → row reads "Allowed".
- [ ] With denied status, schedule a session for tomorrow; `Log` (Console.app, subsystem
  `com.madacgrav.trainme`) shows "Skipping … session alerts".

---

## Phase 5: Calendar fallback, typed error, and non-blocking calendar warnings (#26, part of #24)

### Changes

#### 1. Calendar service
**File**: `Sources/Services/CalendarService.swift` — **modify**
```swift
enum CalendarError: Error, Equatable {
    /// No default calendar and no calendar that allows modifications.
    case noWritableCalendar
}

protocol CalendarSyncing: Sendable {
    func requestAccess() async -> Bool
    func authorizationStatus() async -> EKAuthorizationStatus
    func push(...) async throws -> String?
    func update(...) async throws -> String?
    func remove(eventIdentifier: String) async throws
}
```
In `EventKitCalendarService`:
```swift
    func requestAccess() async -> Bool {
        do { return try await store.requestFullAccessToEvents() }
        catch { Log.calendar.error("requestFullAccessToEvents failed: \(error.localizedDescription)"); return false }
    }
    func authorizationStatus() async -> EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .event) }

    private func writableCalendar() throws -> EKCalendar {
        if let d = store.defaultCalendarForNewEvents { return d }
        if let any = store.calendars(for: .event).first(where: { $0.allowsContentModifications }) {
            Log.calendar.info("No default calendar; using \(any.title)")
            return any
        }
        throw CalendarError.noWritableCalendar
    }
```
In `push`, replace `event.calendar = store.defaultCalendarForNewEvents` with
`event.calendar = try writableCalendar()`.

#### 2. Pure outcome resolution
**File**: `Sources/Features/Schedule/EventIdentifierResolution.swift` — **create**
```swift
import Foundation

/// What to do with the stored event identifier after a save's calendar step.
enum CalendarOutcome: Equatable {
    /// Nothing to persist.
    case unchanged
    /// Persist this identifier (nil clears it).
    case store(String?)
    /// Calendar step failed; keep the existing identifier and warn the user.
    case failed(String)
}

/// Pure decision for SessionEditView. `result` is nil when no calendar call was
/// made (toggle off and nothing to remove, or access denied).
func resolveEventIdentifier(
    existing: String?,
    wantsCalendar: Bool,
    hasAccess: Bool,
    result: Result<String?, any Error>?
) -> CalendarOutcome {
    guard wantsCalendar else {
        // Toggle off: `result` is the remove() outcome when an id existed.
        guard existing != nil, let result else { return .unchanged }
        switch result {
        case .success: return .store(nil)
        case .failure: return .failed("Saved, but the calendar event couldn't be removed.")
        }
    }
    guard hasAccess else {
        return existing == nil
            ? .failed("Saved, but calendar access is off. Allow it in Settings to add events.")
            : .unchanged
    }
    switch result {
    case .success(let id?) where id == existing: return .unchanged
    case .success(let id?): return .store(id)
    case .success(nil), .none: return .failed("Saved, but no calendar was available.")
    case .failure(let error):
        if case CalendarError.noWritableCalendar = error {
            return .failed("Saved, but there is no writable calendar on this phone.")
        }
        return .failed("Saved, but the calendar couldn't be updated.")
    }
}
```

#### 3. SessionEditView uses it and reports a warning
**File**: `Sources/Features/Schedule/SessionEditView.swift` — **modify**
- `private let onSaved: (String?) -> Void` (the warning, nil when none); init parameter
  `onSaved: @escaping (String?) -> Void`.
- `@State private var calendarWarning: String?`; reset to nil at the top of `save()`.
- Save button: `if await save() { onSaved(calendarWarning); dismiss() }`.
- Replace the calendar blocks:

New single session (`:220-224`):
```swift
            if addToCalendar {
                let hasAccess = await calendar.requestAccess()
                let result: Result<String?, any Error>? = hasAccess
                    ? await Result { try await calendar.push(dto, clientName: clientName, recurrence: nil) }
                    : nil
                await apply(resolveEventIdentifier(existing: nil, wantsCalendar: true, hasAccess: hasAccess, result: result), to: dto.id)
            }
```
New series (`:198-212`): same shape; on `.store(let id?)` call
`sessionRepo.setEventIdentifierForSeries(series.seriesId, id)` instead.

Edit (`:242-256`):
```swift
        let hasAccess = addToCalendar ? await calendar.requestAccess() : false
        let result: Result<String?, any Error>?
        if addToCalendar, hasAccess {
            result = await Result {
                if let eventId = existing.eventIdentifier {
                    try await calendar.update(eventIdentifier: eventId, updated, clientName: clientName)
                } else {
                    try await calendar.push(updated, clientName: clientName, recurrence: nil)
                }
            }
        } else if !addToCalendar, let eventId = existing.eventIdentifier {
            result = await Result { try await calendar.remove(eventIdentifier: eventId); return nil }
        } else {
            result = nil
        }
        await apply(resolveEventIdentifier(existing: existing.eventIdentifier, wantsCalendar: addToCalendar, hasAccess: hasAccess, result: result), to: updated.id)
        return true
```
Helper:
```swift
    private func apply(_ outcome: CalendarOutcome, to sessionId: UUID) async {
        switch outcome {
        case .unchanged: break
        case .store(let id):
            do { try await sessionRepo.setEventIdentifier(id: sessionId, id) }
            catch {
                Log.calendar.error("setEventIdentifier failed: \(error.localizedDescription)")
                calendarWarning = "Saved, but the calendar link couldn't be recorded."
            }
        case .failed(let message):
            Log.calendar.error("Calendar step failed: \(message)")
            calendarWarning = message
        }
    }
```
`Result { try await ... }` requires an async initializer; add a tiny extension in the same
file if the stdlib one is unavailable:
```swift
extension Result where Failure == any Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
```
Remove the two list-load `try?` at `:153,155`? No — out of scope (list loads stay).

#### 4. Callers show the warning
**File**: `Sources/Features/Schedule/ScheduleView.swift` — **modify**: add
`@State private var calendarWarning: String?`; sheet closure becomes
`{ warning in calendarWarning = warning; Task { await viewModel.load() } }`; add
```swift
            .alert("Calendar", isPresented: Binding(get: { calendarWarning != nil }, set: { if !$0 { calendarWarning = nil } })) {
                Button("OK") { calendarWarning = nil }
            } message: { Text(calendarWarning ?? "") }
```
**File**: `Sources/Features/Session/SessionRunView.swift` — **modify**: same pattern; sheet
closure `{ warning in calendarWarning = warning; Task { await viewModel.reloadAfterEdit() } }`.

#### 5. Settings calendar row
**File**: `Sources/Features/Settings/SettingsView.swift` — **modify**: add
`var calendar: any CalendarSyncing = EventKitCalendarService()` property with default,
`@State private var calendarStatus: EKAuthorizationStatus = .notDetermined` (`import EventKit`),
load it in the same `.task`/scene-phase refresh, and add
`PermissionRow(title: "Calendar", status: calendarStatusText, isDenied: calendarStatus == .denied || calendarStatus == .restricted)`.
Status text: `.fullAccess → "Allowed"`, `.writeOnly → "Write only"`, `.denied/.restricted → "Denied"`, `.notDetermined → "Not asked yet"`.

#### 6. Tests
**File**: `Tests/SessionRunViewModelTests.swift` — **modify** `FakeCalendar`:
```swift
actor FakeCalendar: CalendarSyncing {
    private(set) var removed: [String] = []
    private(set) var updated: [String] = []
    var pushResult: Result<String?, any Error> = .success("evt-new")
    var updateResult: Result<String?, any Error>? = nil   // nil → echo identifier
    var removeError: (any Error)? = nil
    var status: EKAuthorizationStatus = .fullAccess
    func configure(push: Result<String?, any Error>? = nil, update: Result<String?, any Error>? = nil, removeError: (any Error)? = nil) { ... }
    func requestAccess() async -> Bool { status == .fullAccess }
    func authorizationStatus() async -> EKAuthorizationStatus { status }
    func push(...) async throws -> String? { try pushResult.get() }
    func update(eventIdentifier: String, ...) async throws -> String? {
        updated.append(eventIdentifier)
        if let updateResult { return try updateResult.get() }
        return eventIdentifier
    }
    func remove(eventIdentifier: String) async throws {
        if let removeError { throw removeError }
        removed.append(eventIdentifier)
    }
}
```
`import EventKit` at top.

**File**: `Tests/EventIdentifierResolutionTests.swift` — **create**
```swift
import Testing
@testable import TrainMe

private struct Boom: Error {}

@Test func newEventStoresIdentifier() {
    #expect(resolveEventIdentifier(existing: nil, wantsCalendar: true, hasAccess: true, result: .success("e1")) == .store("e1"))
}
@Test func sameIdentifierIsUnchanged() {
    #expect(resolveEventIdentifier(existing: "e1", wantsCalendar: true, hasAccess: true, result: .success("e1")) == .unchanged)
}
@Test func failedUpdateKeepsExistingIdentifier() {
    let outcome = resolveEventIdentifier(existing: "e1", wantsCalendar: true, hasAccess: true, result: .failure(Boom()))
    guard case .failed = outcome else { Issue.record("expected .failed"); return }
}
@Test func noWritableCalendarHasSpecificMessage() {
    let outcome = resolveEventIdentifier(existing: nil, wantsCalendar: true, hasAccess: true, result: .failure(CalendarError.noWritableCalendar))
    #expect(outcome == .failed("Saved, but there is no writable calendar on this phone."))
}
@Test func toggleOffRemoveSuccessClears() {
    #expect(resolveEventIdentifier(existing: "e1", wantsCalendar: false, hasAccess: false, result: .success(nil)) == .store(nil))
}
@Test func toggleOffRemoveFailureKeepsIdentifier() {
    let outcome = resolveEventIdentifier(existing: "e1", wantsCalendar: false, hasAccess: false, result: .failure(Boom()))
    guard case .failed = outcome else { Issue.record("expected .failed"); return }
}
@Test func toggleOffNothingToRemoveIsUnchanged() {
    #expect(resolveEventIdentifier(existing: nil, wantsCalendar: false, hasAccess: false, result: nil) == .unchanged)
}
@Test func deniedAccessWarnsOnlyForNewEvents() {
    guard case .failed = resolveEventIdentifier(existing: nil, wantsCalendar: true, hasAccess: false, result: nil) else { Issue.record("expected .failed"); return }
    #expect(resolveEventIdentifier(existing: "e1", wantsCalendar: true, hasAccess: false, result: nil) == .unchanged)
}
```
**File**: `Tests/CalendarServiceTests.swift` — **create**: `CalendarError` is `Equatable`;
one test asserting `CalendarError.noWritableCalendar == .noWritableCalendar` and that the
protocol has the new requirement via `FakeCalendar().authorizationStatus()`. (Real
`EKEventStore` is not exercised.)

### Verification
#### Automated
- [ ] Test command passes (8 resolution tests + 1 calendar test; existing delete test still green)
- [ ] `grep -n "newId != existing.eventIdentifier" Sources` → none
- [ ] `grep -n "try? await calendar\|try? await sessionRepo.setEventIdentifier" Sources/Features/Schedule/SessionEditView.swift` → none
#### Manual
- [ ] Device, calendar allowed: create session with calendar on → event appears; edit time → event moves; toggle off → event removed.
- [ ] Device, calendar denied: create session with calendar on → session saved, alert "Saved, but calendar access is off…"; Settings Permissions shows Calendar "Denied".
- [ ] Simulator with no calendars: iOS Settings → Calendar → Accounts: remove all; create session with calendar on → "no writable calendar" alert, session saved.

---

## Phase 6: Error-state sweep on run screen, root, and settings (#24, #28 partial)

### Changes

#### 1. SessionRunViewModel
**File**: `Sources/Features/Session/SessionRunViewModel.swift` — **modify**
- Add `var errorMessage: String?`.
- `delete() async -> Bool`:
```swift
    func delete() async -> Bool {
        errorMessage = nil
        if session.seriesId == nil, let eventId = session.eventIdentifier {
            do { try await calendar.remove(eventIdentifier: eventId) }
            catch { Log.calendar.error("remove on delete failed: \(error.localizedDescription)") }  // non-blocking
        }
        do {
            try await sessionRepo.delete(id: session.id)
        } catch {
            Log.ui.error("delete session failed: \(error.localizedDescription)")
            errorMessage = "Couldn't delete the session. Please try again."
            return false
        }
        await onStatusChanged()
        return true
    }
```
- `saveNotes()`: `do/catch` around `updateNotes`; on failure set
  `errorMessage = "Couldn't save notes."` and **return without** refreshing (so the draft is kept).
- `record(...)`: `do/catch` around `recordSet`; on failure set `errorMessage = "Couldn't log that set."` and return before refreshing `recordedSets`.
- `deleteSet`: same, message "Couldn't delete that set."
- `setStatus`: 
```swift
        do { try await sessionRepo.setStatus(id: session.id, status) }
        catch { errorMessage = "Couldn't update the session status."; Log.ui.error(...); return }
        if status == .cancelled, session.seriesId == nil, let eventId = session.eventIdentifier {
            do {
                try await calendar.remove(eventIdentifier: eventId)
                try await sessionRepo.setEventIdentifier(id: session.id, nil)
            } catch {
                Log.calendar.error("cancel cleanup failed: \(error.localizedDescription)")  // keep id for retry
            }
        }
```
- `load()`, `reloadAfterEdit()`, `lastSet`: replace `try?` with `do/catch` that logs at
  `.debug` and keeps the existing fallback (list loads stay non-blocking).

#### 2. SessionRunView
**File**: `Sources/Features/Session/SessionRunView.swift` — **modify**
- Render `errorMessage` as the first `Section` of the main list (match
  `SessionEditView.swift:125-127`: `Text(errorMessage).foregroundStyle(.red)`).
- Delete alert: `Task { if await viewModel.delete() { dismiss() } }`.
- Log-set sheet "Log" button: keep `dismiss()` after `record` (the error shows on the run
  screen behind the sheet).

#### 3. RootView seed failure
**File**: `Sources/RootView.swift` — **modify**
- `@State private var seedFailed = false`.
- `.task`:
```swift
            let container = container
            let seeded: Bool = await Task.detached {
                do { try await SeedImporter.seedIfEmpty(repo: SwiftDataExerciseRepository(modelContainer: container)); return true }
                catch { Log.persistence.error("Seed import failed: \(error.localizedDescription)"); return false }
            }.value
            seedFailed = !seeded
```
- `.alert("Couldn't load the exercise library", isPresented: $seedFailed) { Button("OK") {} } message: { Text("You can add exercises manually from the Exercises tab, or restart the app to try again.") }`.

#### 4. Other mutation sites
**File**: `Sources/Features/Workouts/WorkoutListViewModel.swift` — **modify**: add
`var errorMessage: String?`; `duplicate`/`delete` → `do/catch` setting
"Couldn't duplicate the workout." / "Couldn't delete the workout." and logging via `Log.ui`.
`WorkoutListView` renders it as a red section (find the `List` in
`Sources/Features/Workouts/WorkoutListView.swift`).
**File**: `Sources/Features/Clients/ClientDetailViewModel.swift` — **modify**:
`toggleArchived` → `do/catch`, `errorMessage = "Couldn't update the client."`; add the
property; render in `ClientDetailView` as a red section.
**File**: `Sources/Services/ReminderCoordinator.swift` — `exportReminderIsDue` `try?` → logged `do/catch` with `0` fallback (debug level).

#### 5. Tests
**File**: `Tests/SessionRunViewModelTests.swift` — **modify/add**. Add a failing repository
wrapper in this file:
```swift
/// Wraps a real repository and fails selected calls.
actor FailingSessionRepo: SessionRepository {
    let inner: SwiftDataSessionRepository
    var failDelete = false, failSetStatus = false, failRecordSet = false
    init(inner: SwiftDataSessionRepository) { self.inner = inner }
    func fail(delete: Bool = false, setStatus: Bool = false, recordSet: Bool = false) { failDelete = delete; failSetStatus = setStatus; failRecordSet = recordSet }
    struct Boom: Error {}
    func delete(id: UUID) async throws { if failDelete { throw Boom() }; try await inner.delete(id: id) }
    func setStatus(id: UUID, _ s: SessionStatus) async throws { if failSetStatus { throw Boom() }; try await inner.setStatus(id: id, s) }
    func recordSet(_ dto: SetRecordDTO) async throws { if failRecordSet { throw Boom() }; try await inner.recordSet(dto) }
    // Forward every other SessionRepository requirement to `inner` verbatim
    // (copy signatures from Sources/Persistence/SessionRepository.swift:4-45).
}
```
Tests:
```swift
@MainActor @Test func failedDeleteReturnsFalseAndSetsError() async throws {
    // arrange like deleteRemovesCalendarEventAndSession, but with FailingSessionRepo(fail(delete: true))
    let ok = await vm.delete()
    #expect(!ok)
    #expect(vm.errorMessage != nil)
    #expect(try await sessions.get(id: dto.id) != nil)   // still there
}
@MainActor @Test func failedSetStatusKeepsEventIdentifier() async throws {
    // session stored with eventIdentifier "evt-1"; repo fails setStatus
    await vm.setStatus(.cancelled)
    #expect(vm.errorMessage != nil)
    #expect(try await sessions.get(id: dto.id)?.eventIdentifier == "evt-1")
    #expect(await calendar.removed.isEmpty)
}
@MainActor @Test func failedRecordLeavesSetsUnchanged() async throws {
    await vm.load()
    let before = vm.recordedSets
    await vm.record(instanceId: instanceId, exerciseId: exerciseId, weight: 100, reps: 5, duration: nil, distance: nil)
    #expect(vm.errorMessage != nil)
    #expect(vm.recordedSets == before)
}
```
Use `scheduleSeries`/`schedule` from the real repo to create a session with an instance for
the record test (see `Tests/RecordingTests.swift` for the arrangement).

### Verification
#### Automated
- [ ] Test command passes (3 new view-model tests)
- [ ] `grep -c "try?" Sources/Features/Session/SessionRunViewModel.swift` → 0
- [ ] `grep -rn "try?" Sources | grep -v "removeItem\|contentsOf\|VersionProbe\|JSONEncoder\|JSONDecoder\|Features/.*ViewModel.swift:.*all()\|search(" | wc -l` → small; review each remaining hit is a list load or file cleanup
#### Manual
- [ ] Smoke on device: log a set, delete a set, cancel a session, delete a session, edit notes. No regressions.

---

## Phase 7: Backlog and docs bookkeeping

### Changes
**File**: `BACKLOG.md` — **modify**: move rows 20–27 into a new `## Done` table with the
PR link (`[#NN](https://github.com/madacgrav/trainme/pull/NN)`) in place of Evidence; keep
the issue links. Add a line under the intro: "Tech debt and test gaps from the 2026-10-26
review were addressed in PR #NN."
**File**: `README.md` — **modify**: add a "Permissions" paragraph under Requirements
describing the Settings → Permissions rows and that notifications/calendar are optional.
Ensure the CI badge from Phase 1 is present.
On merge: `gh issue close 22 23 24 25 26 27 28 29 --comment "Closed by #NN"`.

### Verification
#### Automated
- [ ] `grep -c "pull/" BACKLOG.md` ≥ 1; all links in BACKLOG resolve (`gh issue view 22` etc.)
#### Manual
- [ ] `gh issue list --state open` no longer lists #22–#29 after merge

---

## Deviations from structure.md
1. **No `rollback()` on `DataArchiving`.** The rollback happens inside `importData`'s catch,
   which every importer path goes through, so the protocol does not need a new requirement.
2. **Legacy key triggers one backup.** The structure said the legacy key "migrates without
   a spurious backup". The plan instead takes a single `pre-schema-1.0.0` backup when the
   legacy key is present and the new key is absent, because that launch is exactly when the
   unversioned store first opens under `SchemaV1` (design "Open Risks" #2). The test reflects this.
3. **`canScheduleAlerts` pure function** added so the notification gate is testable without
   touching `UNUserNotificationCenter`.
4. **`hasAccess` parameter on `resolveEventIdentifier`** so denied-access produces a warning
   for new events only, matching the "non-blocking warning" goal.
