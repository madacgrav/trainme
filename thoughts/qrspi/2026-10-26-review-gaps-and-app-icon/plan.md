# Implementation Plan

## Overview

Ship a Liquid Glass app icon plus packaging basics, close every PRD P0 gap/partial found
in `research.md` (export reminder, injuries at session time, units, session edit/delete,
confirmations, failed-save surfacing, notification correctness), and leave a durable
backlog (`BACKLOG.md` + GitHub issues) for everything deferred.

**Conventions used below**

- `TEST` = `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -30` run from the repo root **after** `xcodegen generate`.
- `BUILD` = same command with `build` instead of `test`.
- All Swift is Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`. Fakes used in tests must be `actor`s (protocol methods are `async`) so they are `Sendable` for free.
- Do not regenerate `Tests/Fixtures/export-v1.json`.
- Phases are independent except: 6 needs 2; 7 needs the `TabView(selection:)` change made in 2's `RootView` edit (do 2 first). Do phases in order anyway.

**Before Phase 1**

```bash
git checkout -b feature/icon-and-p0-gaps
```

---

## Phase 1: App icon, accent color, packaging keys

### Changes

#### 1. Icon Composer package
**File**: `Sources/AppIcon.icon/icon.json`
**Action**: create. Schema below is copied from a shipped Icon Composer file (verified keys: `fill`, `groups[].layers[].{name,glass,hidden,position,image-name-specializations,blend-mode-specializations}`, `groups[].{shadow,specular,translucency,blur-material}`, `supported-platforms`).

```json
{
  "fill" : "system-light",
  "groups" : [
    {
      "blur-material" : null,
      "layers" : [
        {
          "glass" : false,
          "hidden" : false,
          "image-name-specializations" : [ { "value" : "background.svg" } ],
          "name" : "background",
          "position" : { "scale" : 1, "translation-in-points" : [ 0, 0 ] }
        }
      ],
      "shadow" : null,
      "specular" : false,
      "translucency" : { "enabled" : false, "value" : 0 }
    },
    {
      "blur-material" : null,
      "layers" : [
        {
          "glass" : true,
          "hidden" : false,
          "image-name-specializations" : [ { "value" : "dumbbell.svg" } ],
          "name" : "dumbbell",
          "position" : { "scale" : 0.78, "translation-in-points" : [ 0, 20 ] }
        },
        {
          "glass" : true,
          "hidden" : false,
          "image-name-specializations" : [ { "value" : "line.svg" } ],
          "name" : "rising line",
          "position" : { "scale" : 0.82, "translation-in-points" : [ 0, -60 ] }
        }
      ],
      "shadow" : { "kind" : "layer-color", "opacity" : 0.5 },
      "specular" : true,
      "translucency" : { "enabled" : true, "value" : 0.2 }
    }
  ],
  "supported-platforms" : { "circles" : [ "watchOS" ], "squares" : "shared" }
}
```

**Files**: `Sources/AppIcon.icon/Assets/background.svg`, `dumbbell.svg`, `line.svg`
**Action**: create. All three are 1024×1024 `viewBox="0 0 1024 1024"`, square, unmasked, no drop shadows (the system adds corners/glass).

```xml
<!-- background.svg : full-bleed opaque gradient -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0F766E"/>
      <stop offset="1" stop-color="#3730A3"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#g)"/>
</svg>
```

```xml
<!-- dumbbell.svg : white, horizontal, centered -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" fill="#FFFFFF">
  <rect x="312" y="488" width="400" height="48" rx="24"/>
  <rect x="200" y="392" width="96" height="240" rx="28"/>
  <rect x="728" y="392" width="96" height="240" rx="28"/>
  <rect x="128" y="432" width="56" height="160" rx="20"/>
  <rect x="840" y="432" width="56" height="160" rx="20"/>
</svg>
```

```xml
<!-- line.svg : amber rising stroke with end dot -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" fill="none">
  <polyline points="176,700 392,560 560,616 848,328" stroke="#F59E0B" stroke-width="56"
            stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="848" cy="328" r="44" fill="#F59E0B"/>
</svg>
```

#### 2. Asset catalog with accent color
**File**: `Sources/Assets.xcassets/Contents.json`
**Action**: create
```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

**File**: `Sources/Assets.xcassets/AccentColor.colorset/Contents.json`
**Action**: create (amber `#F59E0B`)
```json
{
  "colors" : [
    { "color" : { "color-space" : "srgb",
                  "components" : { "alpha" : "1.000", "blue" : "0.043", "green" : "0.620", "red" : "0.961" } },
      "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

#### 3. project.yml
**File**: `project.yml`
**Action**: modify — add two settings under `targets.TrainMe.settings.base` (after `INFOPLIST_FILE`):
```yaml
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
```
XcodeGen 2.46 maps `.icon` and `.xcassets` to the Resources phase automatically; no `resources:` key is needed.

#### 4. Info.plist
**File**: `Sources/Info.plist`
**Action**: modify — insert before `<key>NSCalendarsFullAccessUsageDescription</key>`:
```xml
	<key>CFBundleDisplayName</key>
	<string>TrainMe</string>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
```
(No `~ipad` key; device family stays `1,2` from the preset.)

#### 5. README
**File**: `README.md`
**Action**: modify — add to "Project layout":
```
- `Sources/AppIcon.icon/` — Icon Composer package (edit `icon.json`/`Assets/*.svg` as text, or open in Icon Composer); `Sources/Assets.xcassets/` holds `AccentColor`
```

#### 6. Fallback (only if step 1 fails validation twice)
Delete `Sources/AppIcon.icon/`; create `Sources/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{ "images" : [ { "filename" : "AppIcon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 } }
```
Render `AppIcon-1024.png` by compositing the three SVGs (e.g. `rsvg-convert` or `qlmanage -t -s 1024`), then strip alpha: `sips -s format png --matchTo '/System/Library/ColorSync/Profiles/sRGB Profile.icc' in.png --out AppIcon-1024.png` and verify `sips -g hasAlpha AppIcon-1024.png` prints `no`. Add a BACKLOG row "Icon Composer package" explaining the fallback.

### Verification
#### Automated
- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun actool Sources/AppIcon.icon --compile /tmp/trainme-icon --app-icon AppIcon --platform iphoneos --target-device iphone --minimum-deployment-target 26.0 --output-partial-info-plist /tmp/trainme-icon.plist` prints no `com.apple.actool.errors` block and `/tmp/trainme-icon/Assets.car` exists (if actool rejects an argument, drop that argument and retry; the authoritative gate is the next line)
- [x] `xcodegen generate` then `grep -c "AppIcon.icon\|Assets.xcassets" TrainMe.xcodeproj/project.pbxproj` ≥ 2 (8)
- [x] `BUILD` succeeds with zero warnings mentioning `AppIcon`
- [x] `TEST` passes (57)
#### Manual
- [x] Boot simulator, install app (`xcrun simctl install booted <path to TrainMe.app>`), press Home: icon shows gradient + white dumbbell + amber line; switch Appearance to Dark (`xcrun simctl ui booted appearance dark`) and re-check
- [x] Toolbar buttons / tinted controls render amber (accent) in the running app
- [x] App name under the icon reads "TrainMe"

---

## Phase 2: ReminderCoordinator — notifications correct from every path

### Changes

#### 1. Scoped removal + pure identifier filter
**File**: `Sources/Services/NotificationService.swift`
**Action**: modify

Add after `selectAlerts`:
```swift
/// Identifiers this app owns. Pure so the filter is unit-testable.
func sessionAlertIdentifiers(from pending: [String]) -> [String] {
    pending.filter { $0.hasPrefix("sess-") }
}
```
Replace `center.removeAllPendingNotificationRequests()` in `reschedule` with:
```swift
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: sessionAlertIdentifiers(from: pending))
```

#### 2. Coordinator
**File**: `Sources/Services/ReminderCoordinator.swift`
**Action**: create
```swift
import Foundation
import Observation

/// Single owner of trainer alerts. Call `refresh()` on foreground and after any
/// session mutation so pending notifications always mirror the store.
@MainActor
@Observable
final class ReminderCoordinator {
    private let sessionRepo: any SessionRepository
    private let clientRepo: any ClientRepository
    private let notifications: any NotificationScheduling

    init(sessionRepo: any SessionRepository, clientRepo: any ClientRepository, notifications: any NotificationScheduling) {
        self.sessionRepo = sessionRepo
        self.clientRepo = clientRepo
        self.notifications = notifications
    }

    func requestAuthorization() async { _ = await notifications.requestAuthorization() }

    /// Re-plans the nearest-N alerts (64-pending budget is enforced in `selectAlerts`).
    func refresh() async {
        let upcoming = (try? await sessionRepo.upcoming(after: .now, limit: 64)) ?? []
        let clients = (try? await clientRepo.allIncludingArchived()) ?? []
        let names = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.name) })
        await notifications.reschedule(upcoming: upcoming.map {
            (id: $0.id, startAt: $0.startAt, clientName: names[$0.clientId] ?? "Client")
        })
    }
}
```

#### 3. ScheduleViewModel
**File**: `Sources/Features/Schedule/ScheduleViewModel.swift`
**Action**: modify
- Replace `let notifications: any NotificationScheduling` with `let reminders: ReminderCoordinator`; init parameter `notifications:` → `reminders: ReminderCoordinator`.
- In `load()` replace `await rescheduleNotifications()` with `await reminders.refresh()`.
- Delete `rescheduleNotifications()`.

#### 4. ClientListViewModel / ClientDetailViewModel / views
**File**: `Sources/Features/Clients/ClientListViewModel.swift`
**Action**: modify — add `let reminders: ReminderCoordinator` + init param `reminders:` (last).

**File**: `Sources/Features/Clients/ClientListView.swift`
**Action**: modify — pass `reminders: viewModel.reminders` into `ClientDetailViewModel(...)` (line 11-17).

**File**: `Sources/Features/Clients/ClientDetailViewModel.swift`
**Action**: modify — add `let reminders: ReminderCoordinator`, init param `reminders:` (after `reporting`), and append `await reminders.refresh()` at the end of `reload()`.

#### 5. RootView — one coordinator, foreground refresh, tab selection
**File**: `Sources/RootView.swift`
**Action**: modify
```swift
struct RootView: View {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenBackupNotice") private var hasSeenBackupNotice = false
    @State private var selectedTab = 0
    @State private var reminders: ReminderCoordinator

    init(container: ModelContainer) {
        self.container = container
        _reminders = State(initialValue: ReminderCoordinator(
            sessionRepo: SwiftDataSessionRepository(modelContainer: container),
            clientRepo: SwiftDataClientRepository(modelContainer: container),
            notifications: LocalNotificationService()
        ))
    }
    ...
        TabView(selection: $selectedTab) {
            Tab("Schedule", systemImage: "calendar", value: 0) { ScheduleView(viewModel: ScheduleViewModel(..., reminders: reminders), openSettings: { selectedTab = 4 }) }
            Tab("Clients", systemImage: "person.2", value: 1) { ClientListView(viewModel: ClientListViewModel(..., reminders: reminders)) }
            Tab("Workouts", systemImage: "list.clipboard", value: 2) { ... }
            Tab("Exercises", systemImage: "dumbbell", value: 3) { ... }
            Tab("Settings", systemImage: "gearshape", value: 4) { ... }
        }
        .onChange(of: scenePhase) { _, phase in
            // `.inactive` fires during Face ID; only a real foreground matters.
            if phase == .active { Task { await reminders.refresh() } }
        }
```
In `.task`, replace `_ = await LocalNotificationService().requestAuthorization()` with `await reminders.requestAuthorization()`. (`openSettings` on `ScheduleView` is added in Phase 7; add the parameter now with a default `= {}` so Phase 2 compiles: `var openSettings: () -> Void = {}`.)

#### 6. Tests
**File**: `Tests/NotificationSchedulingTests.swift`
**Action**: modify — append
```swift
@Test func onlySessionIdentifiersAreRemoved() {
    let ids = ["sess-A-24h", "other-app", "sess-B-1h", "reminder-x"]
    #expect(sessionAlertIdentifiers(from: ids) == ["sess-A-24h", "sess-B-1h"])
}
```

**File**: `Tests/ReminderCoordinatorTests.swift`
**Action**: create
```swift
import Foundation
import Testing
@testable import TrainMe

actor FakeNotifications: NotificationScheduling {
    private(set) var rescheduleCalls: [[UUID]] = []
    func requestAuthorization() async -> Bool { true }
    func reschedule(upcoming: [(id: UUID, startAt: Date, clientName: String)]) async {
        rescheduleCalls.append(upcoming.map(\.id))
    }
}

@MainActor
@Test func refreshReschedulesOnlyScheduledFutureSessions() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let sessions = SwiftDataSessionRepository(modelContainer: container)
    let clients = SwiftDataClientRepository(modelContainer: container)
    let fake = FakeNotifications()
    let sut = ReminderCoordinator(sessionRepo: sessions, clientRepo: clients, notifications: fake)

    let clientId = UUID()
    try await clients.upsert(ClientDTO(id: clientId, name: "Sam", phoneE164: "+15555550100", goal: nil, injuries: nil, notes: nil, isArchived: false, createdAt: .now, updatedAt: .now))
    let future = SessionDTO(id: UUID(), clientId: clientId, startAt: .now.addingTimeInterval(86_400), endAt: .now.addingTimeInterval(90_000), status: .scheduled, notes: nil, instances: [], seriesId: nil, recurrence: nil, eventIdentifier: nil, createdAt: .now, updatedAt: .now)
    var cancelled = future; cancelled = SessionDTO(id: UUID(), clientId: clientId, startAt: future.startAt, endAt: future.endAt, status: .scheduled, notes: nil, instances: [], seriesId: nil, recurrence: nil, eventIdentifier: nil, createdAt: .now, updatedAt: .now)
    try await sessions.schedule(future, attaching: [])
    try await sessions.schedule(cancelled, attaching: [])
    try await sessions.setStatus(id: cancelled.id, .cancelled)

    await sut.refresh()

    let calls = await fake.rescheduleCalls
    #expect(calls.count == 1)
    #expect(calls[0] == [future.id])
}
```

### Verification
#### Automated
- [x] `grep -rn "removeAllPendingNotificationRequests" Sources` → no hits
- [x] `grep -rn "reschedule(upcoming" Sources` → only `NotificationService.swift` (protocol + impl) and `ReminderCoordinator.swift`
- [x] `TEST` passes (59)
#### Manual
- [ ] Create a session for tomorrow, open it from **Clients → detail**, tap Cancelled; background and foreground the app; in Xcode console add a temporary `print(await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier))` in `refresh()` (remove afterward) and confirm no `sess-<thatId>-…` remain

---

## Phase 3: Confirmations and failed-save surfacing

### Changes

#### 1. Delete workout confirmation
**File**: `Sources/Features/Workouts/WorkoutListView.swift`
**Action**: modify
- Add `@State private var pendingDelete: WorkoutDTO?`.
- Swipe "Delete" action body → `pendingDelete = workout`.
- After `.sheet(item: $editingWorkout)` add:
```swift
            .confirmationDialog(
                "Delete \"\(pendingDelete?.name ?? "")\"?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete workout", role: .destructive) {
                    if let id = pendingDelete?.id { Task { await viewModel.delete(id: id) } }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Scheduled sessions keep their own copy; only the template is removed.")
            }
```

#### 2. Status change alerts and delete-set confirmation
**File**: `Sources/Features/Session/SessionRunView.swift`
**Action**: modify
- Add `@State private var pendingStatus: SessionStatus?` to `SessionRunView`.
- "Cancelled" and "No-show" buttons set `pendingStatus = .cancelled` / `.noShow` (leave "Mark Completed" immediate).
- Add after `.sheet(isPresented: $showingTextReminder)`:
```swift
        .alert(
            pendingStatus == .noShow ? "Mark as no-show?" : "Cancel this session?",
            isPresented: Binding(get: { pendingStatus != nil }, set: { if !$0 { pendingStatus = nil } })
        ) {
            Button(pendingStatus == .noShow ? "Mark no-show" : "Cancel session", role: .destructive) {
                if let status = pendingStatus { Task { await viewModel.setStatus(status) } }
                pendingStatus = nil
            }
            Button("Keep", role: .cancel) { pendingStatus = nil }
        } message: {
            Text("This can't be changed back from the app.")
        }
```
- In `PlannedEntryRow`: add `@State private var pendingDeleteSet: SetRecordDTO?`; the "Delete set" button sets it; add on the row's `VStack`:
```swift
        .confirmationDialog("Delete this set?", isPresented: Binding(get: { pendingDeleteSet != nil }, set: { if !$0 { pendingDeleteSet = nil } }), titleVisibility: .visible) {
            Button("Delete set", role: .destructive) {
                if let set = pendingDeleteSet { Task { await viewModel.deleteSet(set) } }
                pendingDeleteSet = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteSet = nil }
        }
```

#### 3. Archive confirmation
**File**: `Sources/Features/Clients/ClientDetailView.swift`
**Action**: modify — add `@State private var confirmingArchive = false`; menu button sets it; add:
```swift
        .confirmationDialog(
            viewModel.client.isArchived ? "Unarchive \(viewModel.client.name)?" : "Archive \(viewModel.client.name)?",
            isPresented: $confirmingArchive, titleVisibility: .visible
        ) {
            Button(viewModel.client.isArchived ? "Unarchive" : "Archive", role: viewModel.client.isArchived ? nil : .destructive) {
                Task { await viewModel.toggleArchived() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.client.isArchived
                 ? "The client returns to the roster and the client picker."
                 : "Archived clients leave the roster and the client picker. Their history is kept.")
        }
```

#### 4. Failed-save surfacing
**File**: `Sources/Features/Clients/ClientEditViewModel.swift`
**Action**: modify — add `var errorMessage: String?`; in `save()` set `errorMessage = nil` at top and `errorMessage = "Couldn't save the client. Please try again."` in the `catch`.

**File**: `Sources/Features/Clients/ClientEditView.swift`
**Action**: modify — after the Notes section:
```swift
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
```

**File**: `Sources/Features/Workouts/WorkoutBuilderViewModel.swift`
**Action**: modify — same `errorMessage` pattern ("Couldn't save the workout. Please try again.").

**File**: `Sources/Features/Workouts/WorkoutBuilderView.swift`
**Action**: modify — add the same red error `Section` after the Exercises section.

**File**: `Sources/Features/Exercises/ExerciseEditView.swift`
**Action**: modify
- Add `@State private var errorMessage: String?`.
- `save()` → `private func save() async -> Bool` using `do { if existing == nil { _ = try await repo.create(dto) } else { try await repo.update(dto) }; return true } catch { errorMessage = "Couldn't save the exercise. Please try again."; return false }`.
- Save button: `Task { if await save() { onSaved(); dismiss() } }`.
- Add red error `Section` after "Default unit".

**File**: `Sources/Features/Schedule/SessionEditView.swift`
**Action**: modify
- Add `@State private var errorMessage: String?`.
- `save()` → `private func save() async -> Bool`. Replace `try? await sessionRepo.scheduleSeries(...)` with a `do/catch` that sets `errorMessage = "Couldn't schedule the session. Please try again."` and returns `false`; same for `try? await sessionRepo.schedule(...)`. Calendar calls stay `try?` (calendar failure must not block saving).
- Save button: `Task { if await save() { onSaved(); dismiss() } }`.
- Add red error `Section` before the calendar toggle section.

### Verification
#### Automated
- [x] `TEST` passes (59)
- [x] `grep -n "role: .destructive" Sources/Features/Workouts/WorkoutListView.swift Sources/Features/Session/SessionRunView.swift Sources/Features/Clients/ClientDetailView.swift | wc -l` ≥ 5 (7)
#### Manual
- [ ] Swipe-delete a workout → dialog; Cancel keeps it; Delete removes it
- [ ] Open a scheduled session → No-show → alert; Keep leaves it scheduled
- [ ] Tap minus on a logged set → dialog
- [ ] Client detail → Archive → dialog with explanation
- [ ] Temporarily make `SwiftDataClientRepository.upsert` throw, Save a client → red message, sheet stays open (revert afterward)

---

## Phase 4: Injuries banner and session notes in the run screen

### Changes

#### 1. View model
**File**: `Sources/Features/Session/SessionRunViewModel.swift`
**Action**: modify
- Add stored properties `var clientInjuries: String?` and `var notesDraft: String`.
- Init: add `clientInjuries: String? = nil` (after `clientPhone`); set `self.clientInjuries = clientInjuries` and `self.notesDraft = session.notes ?? ""`.
- In `load()` after refreshing `session`: `notesDraft = session.notes ?? ""`.
- Add:
```swift
    func saveNotes() async {
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await sessionRepo.updateNotes(id: session.id, trimmed.isEmpty ? nil : trimmed)
        if let refreshed = try? await sessionRepo.get(id: session.id) { session = refreshed }
    }
```

#### 2. View
**File**: `Sources/Features/Session/SessionRunView.swift`
**Action**: modify — insert as the first `List` content, before the Time/Status section:
```swift
            if let injuries = viewModel.clientInjuries, !injuries.isEmpty {
                Section {
                    Label(injuries, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                } header: { Text("Injuries / limitations") }
            }
```
and after the Time/Status section:
```swift
            Section("Notes") {
                TextField("Session notes", text: $viewModel.notesDraft, axis: .vertical)
                    .lineLimit(2...6)
                    .onSubmit { Task { await viewModel.saveNotes() } }
                if viewModel.notesDraft != (viewModel.session.notes ?? "") {
                    Button("Save notes") { Task { await viewModel.saveNotes() } }
                }
            }
```

#### 3. Presenters
**File**: `Sources/Features/Schedule/ScheduleViewModel.swift`
**Action**: modify — add `var clientInjuries: [UUID: String?] = [:]`; in `load()` add `clientInjuries = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.injuries) })`.

**File**: `Sources/Features/Schedule/ScheduleView.swift`
**Action**: modify — pass `clientInjuries: viewModel.clientInjuries[session.clientId] ?? nil` into `SessionRunViewModel(...)`.

**File**: `Sources/Features/Clients/ClientDetailView.swift`
**Action**: modify — pass `clientInjuries: viewModel.client.injuries` in `sessionLink`.

#### 4. Test
**File**: `Tests/SessionRepositoryTests.swift`
**Action**: modify — append
```swift
@Test func updateNotesPersists() async throws {
    let repos = try makeRepos()
    let dto = sessionDTO()
    try await repos.sessions.schedule(dto, attaching: [])
    try await repos.sessions.updateNotes(id: dto.id, "Knee felt fine")
    #expect(try await repos.sessions.get(id: dto.id)?.notes == "Knee felt fine")
    try await repos.sessions.updateNotes(id: dto.id, nil)
    #expect(try await repos.sessions.get(id: dto.id)?.notes == nil)
}
```

### Verification
#### Automated
- [x] `TEST` passes (60)
- [x] `grep -n "injuries" Sources/Features/Session/SessionRunView.swift` ≥ 1 hit (2)
#### Manual
- [ ] Client with injuries "Left knee" → open any of their sessions → orange banner at top
- [ ] Type notes, tap Save notes, pop and re-open → notes persist; empty text clears them

---

## Phase 5: Units honored everywhere

### Changes

#### 1. Formatter
**File**: `Sources/Support/WeightFormatter.swift`
**Action**: create
```swift
import Foundation

/// All weight strings in the app go through here (PRD §4.5). The exercise's
/// `defaultUnit` is the unit of record; nothing is converted.
enum WeightFormatter {
    static func string(_ value: Double, unit: Unit) -> String {
        "\(value.formatted()) \(label(unit))"
    }

    /// "lb" / "kg"; any non-weight unit falls back to "lb" so a mis-set exercise never shows "mi".
    static func label(_ unit: Unit) -> String {
        switch unit {
        case .kg: "kg"
        default: "lb"
        }
    }

    static func stepIncrement(for unit: Unit) -> Double {
        unit == .kg ? 2.5 : 5
    }
}
```

#### 2. Global default
**File**: `Sources/Features/Settings/SettingsView.swift`
**Action**: modify — add `@AppStorage("defaultWeightUnit") private var defaultWeightUnit: String = Unit.lb.rawValue` and, before the Backup section:
```swift
                Section {
                    Picker("Weight unit for new exercises", selection: $defaultWeightUnit) {
                        Text("lb").tag(Unit.lb.rawValue)
                        Text("kg").tag(Unit.kg.rawValue)
                    }
                    .pickerStyle(.segmented)
                } header: { Text("Units") } footer: {
                    Text("Each exercise keeps its own unit; change it from the Exercises tab. Existing weights are never converted.")
                }
```

**File**: `Sources/Features/Exercises/ExerciseEditView.swift`
**Action**: modify — in `init`, replace `existing?.defaultUnit ?? .lb` with
`existing?.defaultUnit ?? (Unit(rawValue: UserDefaults.standard.string(forKey: "defaultWeightUnit") ?? "") ?? .lb)`.

#### 3. Label sweep (8 sites)
**File**: `Sources/Features/Session/SessionRunView.swift`
- `:132` → `parts.append("@ \(WeightFormatter.string(weight, unit: exercise?.defaultUnit ?? .lb))")`
- `:139` → `parts.append(WeightFormatter.string(weight, unit: exercise?.defaultUnit ?? .lb))`
- `SetEntryView`: add `private var weightUnit: Unit { exercise?.defaultUnit ?? .lb }` and `private var step: Double { WeightFormatter.stepIncrement(for: weightUnit) }`; `:166` → `Text("Weight (\(WeightFormatter.label(weightUnit)))")`; `:168`/`:170` buttons → `Button("−\(step.formatted())") { weight = max(0, weight - step) }` / `Button("+\(step.formatted())") { weight += step }`.

**File**: `Sources/Features/Workouts/WorkoutBuilderView.swift`
- `targetSummary` `:92` → needs the unit: change signature to `targetSummary(_ entry: WorkoutEntryDTO, unit: Unit)`; the view model exposes `var exerciseUnits: [UUID: Unit] = [:]` filled in `loadExerciseNames()` (`exerciseUnits = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.defaultUnit) })`, and `addExercise` sets `exerciseUnits[exercise.id] = exercise.defaultUnit`); call site passes `unit: viewModel.exerciseUnits[entry.exerciseId] ?? .lb`.
- `EntryTargetEditView` `:156` → add `let unit: Unit` property; label `Text("Weight (\(WeightFormatter.label(unit)))")`; presenter passes `unit: viewModel.exerciseUnits[viewModel.entries[wrapper.value].exerciseId] ?? .lb`.

**File**: `Sources/Features/Reports/ClientReportView.swift`
- Add `private var selectedUnit: Unit { viewModel.exercisesWithData.first { $0.id == viewModel.selectedExerciseId }?.defaultUnit ?? .lb }`.
- `:27` → `Text(WeightFormatter.string(weight, unit: selectedUnit))`.
- `ExerciseProgressChart`: add `let unitLabel: String` (4th param); `:129` → `.chartYAxisLabel(unitLabel)`; both call sites pass `unitLabel: WeightFormatter.label(selectedUnit)`.
- `renderPDF()` passes `unit: selectedUnit`.

**File**: `Sources/Services/ReportExporter.swift`
- `renderPDF(... personalBest:, unit: Unit)`; `ReportPage` gains `let unit: Unit`; `:81` → `WeightFormatter.string(weight, unit: unit)`; `:85` chart call passes `unitLabel: WeightFormatter.label(unit)`.

#### 4. Test
**File**: `Tests/WeightFormatterTests.swift`
**Action**: create
```swift
import Testing
@testable import TrainMe

@Test func formatsLbAndKg() {
    #expect(WeightFormatter.string(185, unit: .lb) == "185 lb")
    #expect(WeightFormatter.string(82.5, unit: .kg) == "82.5 kg")
}
@Test func nonWeightUnitsFallBackToLb() {
    #expect(WeightFormatter.label(.mi) == "lb")
}
@Test func stepIncrements() {
    #expect(WeightFormatter.stepIncrement(for: .lb) == 5)
    #expect(WeightFormatter.stepIncrement(for: .kg) == 2.5)
}
```

### Verification
#### Automated
- [x] `grep -rn '"lb"\| lb"\|(lb)' Sources/Features Sources/Services` → zero hits (only `WeightFormatter.swift` and `SettingsView.swift` may contain the literal)
- [x] `TEST` passes (63)
#### Manual
- [ ] Settings → Units → kg; create exercise → unit picker preselects kg
- [ ] kg exercise in a workout shows "@ 60 kg"; logging shows ±2.5; report axis and PB say kg; shared PDF says kg

---

## Phase 6: Edit and delete an existing session (non-series)

### Changes

#### 1. Repository
**File**: `Sources/Persistence/SessionRepository.swift`
**Action**: modify — protocol: add after `setStatus`:
```swift
    /// Updates client, time window and notes. Instances are frozen copies and are
    /// never touched here (PRD §4.2).
    func update(_ dto: SessionDTO) async throws
```
Implementation (next to `setStatus`):
```swift
    func update(_ dto: SessionDTO) async throws {
        guard let session = try fetch(id: dto.id) else { return }
        session.clientId = dto.clientId
        session.startAt = dto.startAt
        session.endAt = dto.endAt
        session.notes = dto.notes
        session.updatedAt = .now
        try modelContext.save()
    }
```

#### 2. Calendar update
**File**: `Sources/Services/CalendarService.swift`
**Action**: modify — protocol: add
```swift
    /// Edits the pushed event in place. Returns the identifier to store: the same
    /// one, a new one if the event had vanished and was re-pushed, or nil without access.
    func update(eventIdentifier: String, _ session: SessionDTO, clientName: String) async throws -> String?
```
Implementation:
```swift
    func update(eventIdentifier: String, _ session: SessionDTO, clientName: String) async throws -> String? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        guard let event = store.event(withIdentifier: eventIdentifier) else {
            return try await push(session, clientName: clientName, recurrence: nil)
        }
        event.title = "Training: \(clientName)"
        event.startDate = session.startAt
        event.endDate = session.endAt
        event.notes = session.notes
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }
```

#### 3. SessionEditView — edit mode
**File**: `Sources/Features/Schedule/SessionEditView.swift`
**Action**: modify
- Add `private let existing: SessionDTO?`; init gains `existing: SessionDTO? = nil` (after `calendar:`) and `workoutRepo` becomes `(any WorkoutRepository)?` with default `nil`.
- Init seeds state from `existing`: `selectedClientId`, `startAt = existing.startAt`, `durationMinutes = Int(existing.endAt.timeIntervalSince(existing.startAt) / 60)`, `notes = existing.notes ?? ""`, `addToCalendar = existing.eventIdentifier != nil`.
- Body: wrap the "Workouts" and "Repeat" sections in `if existing == nil { ... }`; title `existing == nil ? "New Session" : "Edit Session"`; calendar toggle label when editing: `"Keep in iPhone calendar"`.
- `.task`: `clients = ...; if let workoutRepo { workouts = (try? await workoutRepo.all()) ?? [] }`.
- `save()` edit branch (first thing after the guard):
```swift
        if let existing {
            var updated = existing
            updated.clientId = clientId
            updated.startAt = startAt
            updated.endAt = startAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            updated.notes = notes.isEmpty ? nil : notes
            do { try await sessionRepo.update(updated) } catch {
                errorMessage = "Couldn't save the session. Please try again."; return false
            }
            let clientName = clients.first { $0.id == clientId }?.name ?? "Client"
            if addToCalendar, await calendar.requestAccess() {
                let newId: String? = if let eventId = existing.eventIdentifier {
                    try? await calendar.update(eventIdentifier: eventId, updated, clientName: clientName)
                } else {
                    try? await calendar.push(updated, clientName: clientName, recurrence: nil)
                }
                if newId != existing.eventIdentifier { try? await sessionRepo.setEventIdentifier(id: updated.id, newId) }
            } else if let eventId = existing.eventIdentifier {
                try? await calendar.remove(eventIdentifier: eventId)
                try? await sessionRepo.setEventIdentifier(id: updated.id, nil)
            }
            return true
        }
```

#### 4. SessionRunViewModel — delete + edit gate
**File**: `Sources/Features/Session/SessionRunViewModel.swift`
**Action**: modify
- Add `let clientRepo: any ClientRepository` + init param `clientRepo:` (after `exerciseRepo`).
- Add `var canEdit: Bool { session.seriesId == nil }`.
- Add:
```swift
    /// Removes the session, its set records (repository handles that) and its
    /// calendar event, then lets the presenter reload and re-plan alerts.
    func delete() async {
        if session.seriesId == nil, let eventId = session.eventIdentifier {
            try? await calendar.remove(eventIdentifier: eventId)
        }
        try? await sessionRepo.delete(id: session.id)
        await onStatusChanged()
    }
```
- Add `func reloadAfterEdit() async { if let refreshed = try? await sessionRepo.get(id: session.id) { session = refreshed; notesDraft = session.notes ?? "" }; await onStatusChanged() }`.

#### 5. SessionRunView — toolbar menu, sheets
**File**: `Sources/Features/Session/SessionRunView.swift`
**Action**: modify
- Add `@Environment(\.dismiss) private var dismiss`, `@State private var showingEdit = false`, `@State private var confirmingDelete = false`, and `var workoutRepo: (any WorkoutRepository)? = nil` (stored property, set by presenters; Schedule passes its repo, Client detail passes nothing).
- Toolbar: wrap the existing text button and a new `Menu` in a `ToolbarItemGroup(placement: .topBarTrailing)`:
```swift
                Menu {
                    if viewModel.canEdit { Button("Edit session", systemImage: "pencil") { showingEdit = true } }
                    Button("Delete session", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
```
- Below the status section add, when `!viewModel.canEdit`: `Section { Text("Part of a repeating series — editing individual occurrences isn't available yet.").font(.footnote).foregroundStyle(.secondary) }`.
- Sheets/alerts:
```swift
        .sheet(isPresented: $showingEdit) {
            SessionEditView(sessionRepo: viewModel.sessionRepo, clientRepo: viewModel.clientRepo,
                            workoutRepo: workoutRepo, existing: viewModel.session, initialDate: viewModel.session.startAt) {
                Task { await viewModel.reloadAfterEdit() }
            }
        }
        .alert("Delete this session?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { Task { await viewModel.delete(); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.canEdit ? "Logged sets for this session are deleted too. This cannot be undone."
                                   : "Only this occurrence is deleted; the rest of the series stays.")
        }
```
- Presenters: `ScheduleView` passes `clientRepo: viewModel.clientRepo` into the VM and `workoutRepo: viewModel.workoutRepo` into the view; `ClientDetailView` passes `clientRepo: viewModel.repository`.
- `SessionEditView` call in `ScheduleView` unchanged except the `workoutRepo:` argument type is now optional (no edit needed).

#### 6. Tests
**File**: `Tests/SessionRepositoryTests.swift`
**Action**: modify — append
```swift
@Test func updateChangesTimeNotInstances() async throws {
    let repos = try makeRepos()
    let template = WorkoutDTO(id: UUID(), name: "Push", entries: [
        WorkoutEntryDTO(id: UUID(), exerciseId: UUID(), order: 0, targetSets: 3, targetReps: 8, targetWeight: 100, targetDuration: nil)
    ], createdAt: .now, updatedAt: .now)
    try await repos.workouts.upsert(template)
    let dto = sessionDTO()
    try await repos.sessions.schedule(dto, attaching: [template.id])
    var edited = try #require(try await repos.sessions.get(id: dto.id))
    let instanceIds = edited.instances.map(\.id)
    edited.startAt = dto.startAt.addingTimeInterval(7200)
    edited.endAt = edited.startAt.addingTimeInterval(1800)
    edited.notes = "moved"
    try await repos.sessions.update(edited)
    let after = try #require(try await repos.sessions.get(id: dto.id))
    #expect(after.startAt == edited.startAt && after.notes == "moved")
    #expect(after.instances.map(\.id) == instanceIds)
}
```

**File**: `Tests/SessionRunViewModelTests.swift`
**Action**: create
```swift
import Foundation
import Testing
@testable import TrainMe

actor FakeCalendar: CalendarSyncing {
    private(set) var removed: [String] = []
    func requestAccess() async -> Bool { true }
    func push(_ session: SessionDTO, clientName: String, recurrence: AppRecurrence?) async throws -> String? { "evt-new" }
    func update(eventIdentifier: String, _ session: SessionDTO, clientName: String) async throws -> String? { eventIdentifier }
    func remove(eventIdentifier: String) async throws { removed.append(eventIdentifier) }
}

@MainActor
@Test func deleteRemovesCalendarEventAndSession() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let sessions = SwiftDataSessionRepository(modelContainer: container)
    let dto = SessionDTO(id: UUID(), clientId: UUID(), startAt: .now, endAt: .now.addingTimeInterval(3600), status: .scheduled, notes: nil, instances: [], seriesId: nil, recurrence: nil, eventIdentifier: nil, createdAt: .now, updatedAt: .now)
    try await sessions.schedule(dto, attaching: [])
    try await sessions.setEventIdentifier(id: dto.id, "evt-1")
    let stored = try #require(try await sessions.get(id: dto.id))
    let calendar = FakeCalendar()
    var reloaded = false
    let vm = SessionRunViewModel(
        sessionRepo: sessions, exerciseRepo: SwiftDataExerciseRepository(modelContainer: container),
        clientRepo: SwiftDataClientRepository(modelContainer: container), calendar: calendar,
        session: stored, clientName: "Sam", onStatusChanged: { reloaded = true }
    )
    await vm.delete()
    #expect(await calendar.removed == ["evt-1"])
    #expect(try await sessions.get(id: dto.id) == nil)
    #expect(reloaded)
}
```

### Verification
#### Automated
- [x] `TEST` passes (65)
- [x] `grep -n "func update" Sources/Persistence/SessionRepository.swift Sources/Services/CalendarService.swift` → 2 hits (2 new implementations; grep also matches the protocol lines and `updateNotes`)
#### Manual
- [ ] Non-series session → ⋯ → Edit session → change time → Save → Schedule list shows new time; if "Add to iPhone calendar" was on, Calendar.app event moved
- [ ] ⋯ → Delete session → alert → Delete → view pops, session gone from Schedule and Client detail
- [ ] Series occurrence → ⋯ shows Delete only; footnote visible; delete removes only that occurrence

---

## Phase 7: Export staleness reminder

### Changes

#### 1. Pure rule
**File**: `Sources/Support/ExportReminder.swift`
**Action**: create
```swift
import Foundation

/// PRD §9: export is the only backup, so nudge when it goes stale. Pure.
func exportReminderDue(
    lastExportAt: Date?,
    now: Date,
    completedSinceExport: Int,
    dayThreshold: Int = 14,
    sessionThreshold: Int = 5
) -> Bool {
    guard let lastExportAt else { return completedSinceExport > 0 }
    let days = Calendar.current.dateComponents([.day], from: lastExportAt, to: now).day ?? 0
    return days >= dayThreshold || completedSinceExport >= sessionThreshold
}
```
(Never exported + nothing recorded → not due, so a fresh install isn't nagged before there is anything to lose.)

#### 2. Count query
**File**: `Sources/Persistence/SessionRepository.swift`
**Action**: modify — protocol: `func completedCount(since: Date?) async throws -> Int`; implementation:
```swift
    func completedCount(since: Date?) async throws -> Int {
        let completedRaw = SessionStatus.completed.rawValue
        let floor = since ?? .distantPast
        return try modelContext.fetchCount(FetchDescriptor<Session>(
            predicate: #Predicate { $0.statusRaw == completedRaw && $0.updatedAt > floor }
        ))
    }
```

#### 3. Schedule view model + banner
**File**: `Sources/Features/Schedule/ScheduleViewModel.swift`
**Action**: modify — add `var exportReminderDue = false` and `private let defaults: UserDefaults`; init gains `defaults: UserDefaults = .standard` (last param). At the end of `load()`:
```swift
        let last = defaults.double(forKey: "lastExportAt")
        let lastExport: Date? = last == 0 ? nil : Date(timeIntervalSince1970: last)
        let completed = (try? await sessionRepo.completedCount(since: lastExport)) ?? 0
        let dismissed = defaults.double(forKey: "exportBannerDismissedAt")
        let recentlyDismissed = dismissed > 0 && Date.now.timeIntervalSince1970 - dismissed < 3 * 86_400
        exportReminderDue = !recentlyDismissed
            && exportReminderDue(lastExportAt: lastExport, now: .now, completedSinceExport: completed)
```
and `func dismissExportReminder() { defaults.set(Date.now.timeIntervalSince1970, forKey: "exportBannerDismissedAt"); exportReminderDue = false }`.

**File**: `Sources/Features/Schedule/ScheduleView.swift`
**Action**: modify — add `var openSettings: () -> Void = {}` (declared in Phase 2); above the `DatePicker`:
```swift
                if viewModel.exportReminderDue {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.exclamationmark").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Back up your data").font(.subheadline.bold())
                            Text("Export is the only backup on this phone.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Export") { openSettings() }.buttonStyle(.borderedProminent).controlSize(.small)
                        Button("Dismiss", systemImage: "xmark") { viewModel.dismissExportReminder() }
                            .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                    .background(.orange.opacity(0.12))
                }
```

#### 4. Settings badge
**File**: `Sources/RootView.swift`
**Action**: modify — `RootView` keeps `@AppStorage("lastExportAt") private var lastExportAt: Double = 0` and `@State private var exportDue = false`; the Settings `Tab` gets `.badge(exportDue ? "!" : nil)`. Compute `exportDue` in `.task` and in the scenePhase `.active` handler via a small helper on `ReminderCoordinator`:
```swift
    // ReminderCoordinator.swift
    func exportReminderIsDue(defaults: UserDefaults = .standard) async -> Bool {
        let last = defaults.double(forKey: "lastExportAt")
        let lastExport: Date? = last == 0 ? nil : Date(timeIntervalSince1970: last)
        let completed = (try? await sessionRepo.completedCount(since: lastExport)) ?? 0
        return exportReminderDue(lastExportAt: lastExport, now: .now, completedSinceExport: completed)
    }
```
and `.onChange(of: lastExportAt) { Task { exportDue = await reminders.exportReminderIsDue() } }` so a successful export clears the badge immediately.

#### 5. Tests
**File**: `Tests/ExportReminderTests.swift`
**Action**: create
```swift
import Foundation
import Testing
@testable import TrainMe

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private func daysAgo(_ d: Int) -> Date { now.addingTimeInterval(-Double(d) * 86_400) }

@Test func neverExportedIsDueOnlyOnceThereIsData() {
    #expect(exportReminderDue(lastExportAt: nil, now: now, completedSinceExport: 0) == false)
    #expect(exportReminderDue(lastExportAt: nil, now: now, completedSinceExport: 1) == true)
}
@Test func underBothThresholdsNotDue() {
    #expect(exportReminderDue(lastExportAt: daysAgo(13), now: now, completedSinceExport: 4) == false)
}
@Test func dayThresholdTriggers() {
    #expect(exportReminderDue(lastExportAt: daysAgo(14), now: now, completedSinceExport: 0) == true)
}
@Test func sessionThresholdTriggers() {
    #expect(exportReminderDue(lastExportAt: daysAgo(1), now: now, completedSinceExport: 5) == true)
}
```

**File**: `Tests/SessionRepositoryTests.swift`
**Action**: modify — append
```swift
@Test func completedCountHonorsSince() async throws {
    let repos = try makeRepos()
    let a = sessionDTO(), b = sessionDTO()
    try await repos.sessions.schedule(a, attaching: [])
    try await repos.sessions.schedule(b, attaching: [])
    try await repos.sessions.setStatus(id: a.id, .completed)
    let mid = Date.now
    try await Task.sleep(for: .milliseconds(20))
    try await repos.sessions.setStatus(id: b.id, .completed)
    #expect(try await repos.sessions.completedCount(since: nil) == 2)
    #expect(try await repos.sessions.completedCount(since: mid) == 1)
}
```

### Verification
#### Automated
- [x] `TEST` passes (70)
#### Manual
- [ ] Fresh simulator install → no banner; complete one session → banner appears on Schedule and "!" badge on Settings
- [ ] Tap Export in banner → lands on Settings; complete an export → banner and badge clear
- [ ] Dismiss → banner hidden; still hidden after relaunch within 3 days

---

## Phase 8: BACKLOG.md, GitHub issues, README link

### Changes

#### 1. Backlog
**File**: `BACKLOG.md`
**Action**: create. Columns: Item · Why / PRD ref · Evidence · Issue. Rows (fill the Issue column in step 2):

**P1 — features**
1. Session volume per session/week — PRD §8 P1 — no `volume` in Sources
2. Training consistency (completed vs scheduled; cancelled/no-show counted) — PRD §8 P1
3. Client-level summary of top exercises — PRD §8 P1
4. Per-exercise history list (dates, weights, reps) — PRD §5.6 — `ReportingQueries.history` has no list UI
5. Series edit/cancel + shared calendar event update/removal — decisions #3/#4 — `SessionRunViewModel.setStatus` skips series
6. Week view on Schedule — PRD §5.4 — `ScheduleView` is day-only
7. Inline "create exercise" from the workout picker — PRD §4.3 — `ExercisePickerView` has no create action
8. Browse/unarchive archived clients — PRD §5.1 — no list uses `allIncludingArchived`
9. Report as PNG image — PRD §5.9 "PDF/image" — `ReportExporter` is PDF-only
10. Total-reps progression chart — PRD §8 P0 alt — only Epley 1RM exists

**P2 — features**
11. CSV export of session history — PRD §9
12. Daily / every-N-weeks recurrence in the UI — `AppRecurrence` supports it; `SessionEditView` is weekly-only
13. RPE input when logging a set — `SetRecord.rpe` always nil
14. Delete client / delete exercise — repository methods exist, no UI
15. Settings toggles: app lock on/off, calendar default, notification lead times
16. Reorder workout entries via edit mode (`.onMove` wired, no `EditButton`)
17. Session notes on the Schedule row / client detail row

**Deferred by owner decision**
18. Double-booking detection (decisions #3: out)
19. Direct Google Calendar API (decisions #4: share-sheet/default calendar only)

**Tech debt**
20. `VersionedSchema` + `SchemaMigrationPlan` (plan.md §cross-phase said "from first release")
21. Pre-import automatic backup and import rollback on partial failure
22. Replace `try?` with surfaced errors in remaining background paths (seed import, calendar push)
23. Notification authorization status check before `add`; re-prompt path when denied
24. `defaultCalendarForNewEvents == nil` handling
25. Privacy manifest (`PrivacyInfo.xcprivacy`), entitlements file, CI workflow (`xcodebuild test` on PR)

**Test gaps**
26. AppLock, EventKit write path, notification delivery, ReportExporter, view models, UI/snapshot tests
27. Replace-import into a non-empty store; `importArchive(url:)` failure paths

Add at the bottom: "Generated from the 2026-10-26 review (`thoughts/qrspi/2026-10-26-review-gaps-and-app-icon/research.md`). Items that were P0 were fixed in the same PR."

#### 2. GitHub issues (run only after the owner approves `BACKLOG.md` text)
```bash
gh label create "priority:P1" --color D93F0B --description "Strongly desired next" --force
gh label create "priority:P2" --color FBCA04 --description "Nice to have" --force
gh label create "tech-debt" --color 5319E7 --description "Internal quality / robustness" --force
# one call per row, e.g.:
gh issue create --label "enhancement,priority:P1" \
  --title "Reporting: session volume per session/week" \
  --body "$(printf 'PRD §8 P1.\n\nEvidence: no volume computation in Sources (research.md Q1).\n\nSee BACKLOG.md row 1.')"
```
Use `enhancement,priority:P1` for rows 1–10, `enhancement,priority:P2` for 11–17, `wontfix` for 18–19 (open and immediately close with a comment citing decisions.md), `tech-debt` for 20–27. Capture each URL (`gh issue create` prints it) and write it into the Issue column.

#### 3. README
**File**: `README.md`
**Action**: modify — after the first paragraph: `Roadmap and known gaps: see [BACKLOG.md](BACKLOG.md).`

#### 4. Commit + PR
```bash
git add -A && git commit -m "Add app icon, close P0 gaps, add BACKLOG" # (one commit per phase is also fine)
git push -u origin feature/icon-and-p0-gaps
gh pr create --base fix/review-findings --title "App icon, P0 gap fixes, backlog" --body-file <generated body>
```
PR body summarises phases 1–8 and ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

### Verification
#### Automated
- [ ] `gh issue list --label priority:P1 --state all | wc -l` = 10; `--label priority:P2` = 7; `--label tech-debt` = 8
- [ ] `grep -c "github.com/madacgrav/trainme/issues/" BACKLOG.md` = 27
- [ ] `grep -n "BACKLOG.md" README.md` ≥ 1
- [ ] `TEST` passes (70); `git status` clean
#### Manual
- [ ] Open `BACKLOG.md` on GitHub: every Issue link resolves; wontfix rows are closed
- [ ] PR opened and CI (none yet) not required; PR description lists manual checks performed

---

## Final checklist (whole PR)

- [ ] `TEST` green at 70 tests
- [ ] `grep -rn '"lb"\| lb"\|(lb)' Sources/Features Sources/Services` → 0
- [ ] `grep -rn removeAllPendingNotificationRequests Sources` → 0
- [ ] Simulator: icon (light/dark), accent, injuries banner, confirmations, kg labels, session edit/delete, export banner all observed
- [ ] `BACKLOG.md` committed, issues created, README linked
