# Research Findings

All paths are relative to the repository root. Line numbers are as of commit 73835e4.

## Q1: ModelContainer construction, launch recovery, and the three "versions"

### Findings
**Launch sequence (all on the main actor, synchronous):**
- `TrainMeApp` holds `@State private var bootstrap = AppBootstrap()` (`Sources/TrainMeApp.swift:46-47`). `AppBootstrap` is `@MainActor @Observable` (`:4-6`).
- `AppBootstrap.init` (`:15-19`): reads `CFBundleShortVersionString` (fallback `"0"`, `:16`), calls `try? StoreBackup.backupIfVersionChanged(...)` (`:17`, error swallowed), then `state = Self.attempt()` (`:18`).
- `attempt()` (`:37-43`) wraps `PersistenceController.makeContainer()`; success → `.ready(container)`, any throw → `.failed(error.localizedDescription)`.
- `PersistenceController.makeContainer(inMemory:)` (`Sources/Persistence/PersistenceController.swift:11-18`): `try?` creates Application Support (`:14`), builds `ModelConfiguration(isStoredInMemoryOnly:)` with no explicit URL or name (`:16`), then `ModelContainer(for: Schema(schemaTypes), configurations: config)` (`:17`). `schemaTypes` is a plain `[any PersistentModel.Type]` of 8 types (`:6-9`).
- No `VersionedSchema`, `SchemaMigrationPlan`, or `MigrationStage` exists anywhere in `Sources/`; the only mention is `BACKLOG.md:49`. Schema changes rely on SwiftData lightweight migration; model files carry `= default` values for that purpose (`Sources/Models/Client.swift:8` comment).
- `AppBootstrap.storeURL` is hard-coded to `applicationSupportDirectory/default.store` (`TrainMeApp.swift:13`), mirroring SwiftData's default location rather than being passed to the configuration.
- `WindowGroup` switches on `bootstrap.state` (`:51-64`): `.ready` → `LockGateView { RootView(container:) }`; `.failed` → `RecoveryView`.
- `LockGateView` (`Sources/Features/Lock/LockGateView.swift:5-31`) gates `RootView` behind Face ID; `RootView` is created only after unlock.
- `RootView.task` (`Sources/RootView.swift:81-88`): `Task.detached { try? SeedImporter.seedIfEmpty(...) }`, then `reminders.requestAuthorization()`, then `exportDue`.

**Recovery branches (`TrainMeApp.swift`):**
- No automatic recovery. A failed open sets `.failed(message)` only.
- "Restore last backup" → `restoreBackupAndRetry` (`:22-25`): `try? StoreBackup.restoreLatest`, then `attempt()` again.
- "Start fresh" → `resetStoreAndRetry` (`:29-35`): `try? removeItem` on `default.store`, `-wal`, `-shm`, then `attempt()`. `Backups/` and `lastRunAppVersion` are left untouched. Seed import then runs on the empty store via `RootView.task`.
- `RecoveryView` (`:68-100`): shows headline, `localizedDescription`, a "Restore last backup" button (`:86`), and a destructive "Start fresh" button behind a confirmation alert (`:88-98`). No import action is offered there; the alert text points to Settings.

**Three independent version concepts:**
| Concept | Value | Where compared |
|---|---|---|
| App marketing version | `CFBundleShortVersionString` = `1.0` (`Sources/Info.plist:17-18`) | `StoreBackup.backupIfVersionChanged` vs `UserDefaults["lastRunAppVersion"]` (`StoreBackup.swift:6,20`) |
| Archive schema version | `ArchiveV1.schemaVersion = 1` (`Sources/Services/Archive/ArchiveV1.swift:9`) | `DataArchive.swift:74` (`probe.schemaVersion <= 1`) |
| SwiftData schema | unversioned `Schema(schemaTypes)` | never |

- `Envelope.appVersion` (`ArchiveV1.swift:14`) is written from the same plist key (`DataArchive.swift:27`) but never read on import.
- `StoreBackup` triggers on marketing-version change only; a model edit without a version bump produces no backup, and a version bump without a model change produces one.

**@Model types (`Sources/Models/`):** Client (`Client.swift:4`), Exercise (`Exercise.swift:34`), Workout (`Workout.swift:4`), WorkoutEntry (`:21`), Session (`Session.swift:22`), WorkoutInstance (`:67`), PlannedEntry (`:83`), SetRecord (`SetRecord.swift:4`). All have `@Attribute(.unique) id: UUID`. Only three `@Relationship`s exist, all `.cascade`: Workout→entries (`Workout.swift:8`), Session→instances (`Session.swift:30`), WorkoutInstance→plannedEntries (`Session.swift:72`). All other links (`clientId`, `exerciseId`, `workoutInstanceId`, `sourceWorkoutId`) are bare UUIDs with no delete rule.

## Q2: Replace vs merge import, failure mid-import, and StoreBackup

### Findings
**Export (`Sources/Services/Archive/DataArchive.swift:24-48`):** five separate fetches (`:28-32`) → `CurrentArchive` envelope → JSON with `.iso8601`, `.prettyPrinted`, `.sortedKeys` (`:34-37`) → `removeExports()` (`:44`, `try?`) → recreate `tmp/Exports/` → atomic write with `.completeFileProtection` (`:46`). File name `TrainMe Export yyyy-MM-dd.json` (`:42-43`).

**Import (`DataArchive.swift:58-86`):**
1. `importArchive` wraps security-scoped access; `try? Data(contentsOf:)` failure → `ArchiveError.unreadable` (`:63`).
2. `importData`: `VersionProbe` decode failure → `.unreadable` (`:71-73`); `schemaVersion > 1` → `.newerThanApp` (`:74-76`).
3. Full decode `try decoder.decode(CurrentArchive.self)` (`:79`) — raw `DecodingError`, not `ArchiveError`. All of steps 1-3 precede any mutation.
4. `.replace` only: `try deleteAll()` (`:81-83`, `:90-96`) — `delete(model:)` on SetRecord, Session, Workout, Exercise, Client in that order. WorkoutEntry/WorkoutInstance/PlannedEntry rely on cascade.
5. `try upsertAll(envelope)` (`:84`, `:100-144`) — same code for both modes. Clients/Exercises update in place (`ClientDTO.swift:30-38` sets `updatedAt = .now`); Workouts, Sessions, SetRecords are delete-then-insert by id. Sessions rebuilt via `insertSessionGraph` (`:149-170`).
6. Single `try modelContext.save()` (`:85`). This is the only save in the import path.

**Failure partway:** no `do/catch`, `rollback()`, `transaction {}`, or `autosaveEnabled` assignment exists in `Sources/` (grep). A throw in `deleteAll` or `upsertAll` propagates out with staged deletes/inserts left on the actor's `modelContext`; the save at `:85` is skipped. `DataArchiveActor` is created once per Settings tab closure (`RootView.swift:59`) and held as `let archive` by `SettingsView`, so a second import reuses the same context. Whether leftover staged changes persist on a later save depends on SwiftData's autosave default for a `@ModelActor` context, which the code does not set.

**SettingsView handling (`Sources/Features/Settings/SettingsView.swift`):**
- Export: `exportURL = try? await archive.export()` (`:42`); on failure the exporter silently does not appear.
- `.fileExporter` / `.fileImporter` completions handle only `.success` (`:69`, `:78`).
- Replace requires `confirmationDialog` (`:83-91`) then `.alert("Replace everything?")` (`:92-99`).
- `runImport` (`:103-114`): `catch ArchiveError.newerThanApp` → "newer version" text; generic `catch` → "Import failed: the file couldn't be read." (covers `DecodingError`, delete/fetch/save failures alike). Shown as secondary `Text` (`:56-60`), never cleared.

**StoreBackup (`Sources/Persistence/StoreBackup.swift`):**
- Runs only from `AppBootstrap.init` (`TrainMeApp.swift:17`), before container open. No caller around imports (grep: only `TrainMeApp.swift:17,23`).
- Copies only when a stored `lastVersion` exists and differs (`:20`). First-ever launch: records version, no copy. Deletes whole `Backups/` first (`:23`, `try?`), creates `Backups/pre-<currentVersion>/` (`:24-25`), copies `""`, `-wal`, `-shm` if present (`:27-32`), records version only after success (`:34`). One backup retained.
- `restoreLatest` (`:38-55`): lists `Backups/` (throws if absent), picks first `pre-` entry (`:41`), removes live store files (`:46-51`), copies backup files over (`:52-54`). Backup not removed afterwards.

**Existing tests (`Tests/ArchiveRoundTripTests.swift`, `Tests/StoreBackupTests.swift`):** round trip into fresh store (`:65`), merge upsert by id (`:99`), newer version rejected (`:129`), unreadable rejected (`:138`), golden v1 fixture (`:148`); backup on version change + restore, WAL removal on restore, failed backup not recorded. Not covered: replace into non-empty store, merge over existing sessions/workouts/sets, any throw after decode, state after failed import, `restoreLatest` with missing folder, export file naming/cleanup, SettingsView messages.

## Q3: Swallowed errors and existing surfacing patterns

### Findings
**Scale:** 69 lines in `Sources/` contain `try?`. No `catch {}` with an empty body exists; no `print`, `NSLog`, `os_log`, or `Logger` call exists anywhere in `Sources/`. Every `catch` assigns a fixed string; only `TrainMeApp.swift:41` keeps `error.localizedDescription`.

**A1. RootView / reminders:**
- `RootView.swift:84` `try? SeedImporter.seedIfEmpty` inside `Task.detached`. `seedIfEmpty` (`Sources/Persistence/SeedImporter.swift:14-41`) can throw from `count()`, decode, `createAll`. Missing resource is a silent `return` (`:16`). Result: empty exercise library, no signal.
- `ReminderCoordinator.swift:31` `completedCount ?? 0`; `:37` `upcoming ?? []`; `:38` `allIncludingArchived ?? []`. A failed `upcoming` fetch makes `reschedule(upcoming: [])` run, which removes all pending `sess-` alerts (`NotificationService.swift:72`) and adds none.
- `NotificationService.swift:64` `requestAuthorization ?? false`; `:85` `try? center.add`.

**A2. SessionEditView (`Sources/Features/Schedule/SessionEditView.swift`):** primary store writes are in `do/catch` → `errorMessage` (`:192-197`, `:214-219`, `:236-241`). Everything calendar-related is `try?`: `:153,155` list loads; `:209` series push, `:210` `setEventIdentifierForSeries`; `:222` push, `:223` `setEventIdentifier`; `:245` update, `:247` push, `:250` `setEventIdentifier(newId)`, `:253` remove, `:254` `setEventIdentifier(nil)`. Comment at `:220`: "Calendar failures never block saving". `save()`/`saveEdit()` return `true` regardless of calendar outcome (`:226`, `:256`). At `:249-251`, a failed `update` yields `newId == nil`, which differs from the existing id, so the stored identifier is overwritten with nil.

**A3. SessionRunViewModel (`Sources/Features/Session/SessionRunViewModel.swift`):** `@MainActor @Observable`, no error property, no `catch` blocks. `try?` at `:51,54,56,65,76,78,84,85,111,112,116,117,121,125,130,131,133`. Notable: `delete()` (`:74-80`) swallows `sessionRepo.delete` and the view dismisses regardless (`SessionRunView.swift:107-110`); `saveNotes()` (`:84-85`) can silently revert `notesDraft` if update fails but `get` succeeds; `setStatus` (`:124-137`) clears the event identifier even if `calendar.remove` threw.

**A4. SettingsView:** `:42` export `try?`; `:69,78` ignored `.failure` results; `DataArchive.swift:55,63,71,157` `try?` (two of which convert to `.unreadable`).

**A5. Elsewhere:** `ScheduleViewModel.swift:45,47,59`; `ClientDetailViewModel.swift:37,40,62`; `ClientListViewModel.swift:30`; `WorkoutListViewModel.swift:17,21,26`; `WorkoutBuilderViewModel.swift:32`; `WorkoutBuilderView.swift:143,145`; `ExerciseListViewModel.swift:22`; `ClientReportViewModel.swift:25,26,40,41`; `ClientReportView.swift:90` (PDF render → nil); `ReportExporter.swift:54`; `AppLock.swift:40`; `SessionRepository.swift:127,300`, `SessionDTO.swift:83` (recurrence JSON); `PersistenceController.swift:14`; `StoreBackup.swift:23`; `TrainMeApp.swift:17,23,32`.

**B. Surfacing patterns that exist:**
| Pattern | Example | Mechanism |
|---|---|---|
| B1 View-owned `@State errorMessage` + red `Section` | `SessionEditView.swift:20,125-127,163`; `ExerciseEditView.swift:18,74-76,111-121` | `save() async -> Bool`; `false` keeps sheet open |
| B2 View-model `var errorMessage: String?` | `ClientEditViewModel.swift:15,49-55` → `ClientEditView.swift:34-36`; `WorkoutBuilderViewModel.swift:15,78-84` → `WorkoutBuilderView.swift:47-49` | same `save() -> Bool` contract |
| B3 Settings `statusMessage` (secondary color, success+failure) | `SettingsView.swift:16,56-60,71,107-111` | set in `runImport`; never cleared |
| B4 Typed error enum | `ArchiveError` (`DataArchive.swift:8-11`): `newerThanApp(Int)`, `unreadable` | only custom error type in `Sources/`; mapped at `SettingsView.swift:108-111` |
| B5 Full-screen `RecoveryView` | `TrainMeApp.swift:6-44,50-64,68-100` | `@Observable` state enum on bootstrap; only place `localizedDescription` is shown |
| B6 Inline banner | Export reminder `ScheduleView.swift:12-34`, backed by `ScheduleViewModel.swift:20,56-71` | not parameterised; not reusable |
| B7 `.alert(` | `RootView.swift:63`, `SessionRunView.swift:105,130`, `SettingsView.swift:92`, `TrainMeApp.swift:93` | all confirmations/notices; none bound to an error |

No shared error type, helper, protocol, or `LocalizedError` conformance exists. View models with no error property: `SessionRunViewModel`, `ScheduleViewModel`, `WorkoutListViewModel`, `ClientDetailViewModel`, `ClientListViewModel`, `ExerciseListViewModel`, `ClientReportViewModel`.

## Q4: Notifications

### Findings
- `protocol NotificationScheduling: Sendable` (`Sources/Services/NotificationService.swift:56-60`): `requestAuthorization() async -> Bool`, `reschedule(upcoming:) async` (non-throwing, Void).
- `LocalNotificationService` (`:62`) is stateless; `requestAuthorization` (`:63-66`) returns `(try? ... requestAuthorization(options: [.alert, .sound, .badge])) ?? false`. Thrown error and denial are indistinguishable.
- The Bool is discarded by the only caller: `ReminderCoordinator.requestAuthorization()` does `_ = await notifications.requestAuthorization()` (`Sources/Services/ReminderCoordinator.swift:23-25`), called once from `RootView.swift:86`.
- `reschedule` (`:68-91`): reads pending identifiers (`:71`), removes those with prefix `sess-` via `sessionAlertIdentifiers` (`:72`, `:52-54`), then for each `selectAlerts(...)` result (`:74`) builds content + `UNCalendarNotificationTrigger` (`:75-84`) and `try? await center.add(...)` (`:85`). Removal precedes adds; failed adds leave the old requests already gone.
- `selectAlerts` (`:15-49`): `cap = 64` → `maxSessions = 32`; 24h and 1h alerts per session, identifiers `sess-<uuid>-24h` / `-1h`. The cap counts only session alerts, not other pending requests.
- `getNotificationSettings` / `authorizationStatus` for notifications is read nowhere in `Sources/` (grep hits only EventKit at `CalendarService.swift:54,69`). `reschedule` does not check authorization.
- Current behavior: not-determined → system prompt from `RootView.task`; `refresh()` can run before the answer (triggered by `scenePhase == .active` at `RootView.swift:68-75`, `ScheduleViewModel.swift:52`, `ClientDetailViewModel.swift:46`). Denied → `false` discarded, `reschedule` still removes/adds, adds fail silently. No UI state reflects notification status; no Info.plist key is involved.
- `ReminderCoordinator.refresh()` (`:36-43`): `upcoming(after:limit: 64)` (`SessionRepository.swift:164-172`, scheduled only, sorted), `allIncludingArchived()`, name fallback `"Client"`.
- Tests: `Tests/NotificationSchedulingTests.swift` covers only pure helpers (`:9-46`). `FakeNotifications` (`Tests/ReminderCoordinatorTests.swift:5-13`) always returns `true`, records only IDs. Single coordinator test at `:25-49`. No test for denied status, failed add, or `requestAuthorization`.

## Q5: Calendar

### Findings
- `protocol CalendarSyncing: Sendable` (`Sources/Services/CalendarService.swift:34-44`): `requestAccess() -> Bool`, `push(...) throws -> String?`, `update(eventIdentifier:...) throws -> String?`, `remove(eventIdentifier:) throws`. Conformer `actor EventKitCalendarService` with `private let store = EKEventStore()` (`:46-47`).
- `requestAccess` (`:49-51`): `(try? await store.requestFullAccessToEvents()) ?? false`. Plist key `NSCalendarsFullAccessUsageDescription` (`Sources/Info.plist:27-28`).
- `push` (`:53-66`): returns `nil` unless `authorizationStatus(for: .event) == .fullAccess` (`:54`); builds `EKEvent` with title `"Training: <name>"`, dates, notes; `event.calendar = store.defaultCalendarForNewEvents` (`:60`) — the only assignment, direct from an `EKCalendar?` with no nil check; recurrence via `makeEKRecurrenceRule` (`:6-32`); `store.save(event, span: .futureEvents, commit: true)` (`:64`) propagates throws.
- `update` (`:68-80`): nil without full access; event not found → re-`push` with `recurrence: nil` (`:70-73`); otherwise sets title/dates/notes, saves `span: .thisEvent`, does not touch calendar or recurrence.
- `remove` (`:82-85`): no authorization check; missing event → silent return; else `store.remove(span: .futureEvents)`.
- Callers: `SessionEditView` defaults `calendar` to `EventKitCalendarService()` (`:32`); no call site overrides it (`ScheduleView.swift:67-74`, `SessionRunView.swift:95-103`). Branches: new single (`:220-224`), new series with anchored first occurrence and `occurrenceCount` bound (`:198-212`, `setEventIdentifierForSeries` → `SessionRepository.swift:207-216`), edit (`:242-256`, see Q3 A2 for the nil-overwrite path). `SessionRunViewModel` defaults likewise (`:31`); it only calls `remove` (`:76`, `:130`) and only for non-series sessions (`seriesId == nil`). `canEdit = session.seriesId == nil` (`:25`).
- `setEventIdentifier` (`SessionRepository.swift:200-205`) is a no-op for an unknown id, else sets id, bumps `updatedAt`, saves.
- Tests: `FakeCalendar` (`Tests/SessionRunViewModelTests.swift:5-23`) records `removed`/`updated`, returns `true`/`"evt-new"`, never throws or returns nil. One test, `deleteRemovesCalendarEventAndSession` (`:30-62`). `Tests/CalendarMappingTests.swift` covers `makeEKRecurrenceRule` only. No test constructs `SessionEditView` or `EventKitCalendarService`; none covers nil default calendar, denied access, or missing event.

## Q6: Build and packaging configuration

### Findings
- `project.yml`: iOS 26.0 deployment target (`:2-4`); `SWIFT_VERSION 6.0`, `SWIFT_STRICT_CONCURRENCY complete` (`:6-9`). Target `TrainMe` (`:11-23`): `DEVELOPMENT_TEAM ZD9JLCY7TF`, `CODE_SIGN_STYLE Automatic`, bundle id `com.madacgrav.trainme`, `GENERATE_INFOPLIST_FILE NO`, `INFOPLIST_FILE Sources/Info.plist`, `AppIcon`, `AccentColor`. Target `TrainMeTests` (`:24-32`): `bundle.unit-test`, sources `Tests`, depends on `TrainMe`, generated plist. Scheme `TrainMe` (`:33-39`): builds `TrainMe`, tests `TrainMeTests`. No `CODE_SIGN_ENTITLEMENTS`, `capabilities`, `configFiles`, `packages`, or custom configurations.
- Generated pbxproj (untracked): `TARGETED_DEVICE_FAMILY "1,2"` (XcodeGen default), `TEST_HOST` set, `CODE_SIGN_IDENTITY "iPhone Developer"`. Scheme file: test action Debug, `parallelizable = NO`, no coverage targets specified.
- `Sources/Info.plist`: standard bundle keys, `CFBundleShortVersionString 1.0`, `CFBundleVersion 1`, portrait only, `NSCalendarsFullAccessUsageDescription`, `NSFaceIDUsageDescription`, empty `UILaunchScreen`. Absent: `ITSAppUsesNonExemptEncryption`, `UIBackgroundModes`, scene manifest, URL schemes.
- No `*.entitlements`, `PrivacyInfo.xcprivacy`, `*.xcconfig`, Fastfile, Makefile, or shell scripts anywhere outside `build/`.
- `.github/` contains only `CODEOWNERS` (`* @madacgrav`). No workflows, templates, or dependabot config.
- `.gitignore`: `build/`, `DerivedData/`, `xcuserdata/`, `*.xcworkspace`, `*.xcodeproj` (`:5-11`). `git ls-files TrainMe.xcodeproj` returns nothing; the project is generated, not committed.
- Frameworks imported: EventKit (`CalendarService.swift:1`), UserNotifications (`NotificationService.swift:2`), LocalAuthentication (`AppLock.swift:2`), MessageUI (`MessagingService.swift:2`), Charts (`ClientReportView.swift:1`), UniformTypeIdentifiers (`SettingsView.swift:3`), SwiftData, Observation, UIKit (`ReportExporter.swift:2`), SwiftUI, Foundation. No PDFKit; no third-party packages.
- README build/test (`README.md:14-37`): `brew install xcodegen`, `xcodegen generate`, `xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' test`. `DEVELOPER_DIR` workaround documented. Requires Xcode 26+. No device build or signing notes.

## Q7: Test target organization

### Findings
- Framework: Swift Testing throughout (`import Testing`, `@Test`, `#expect`, `#require`); no XCTest. Top-level free functions; no `@Suite`, no `.serialized`. `@MainActor` on view-model and coordinator tests. `@testable import TrainMe` everywhere.
- 19 test files + `Tests/Fixtures/export-v1.json` (loaded via `Bundle(for: BundleToken.self)`, `ArchiveRoundTripTests.swift:7,149-150`).
- Persistence tests build `try PersistenceController.makeContainer(inMemory: true)` per test and construct real `SwiftData*Repository` actors from it (`ClientRepositoryTests.swift:6`, `SessionRepositoryTests.swift:11`, `ArchiveRoundTripTests.swift:19` via `makeEnv()`, `ReminderCoordinatorTests.swift:27`, `SessionRunViewModelTests.swift:32`, etc.). No repository fakes.
- Doubles: `FakeCalendar` (`SessionRunViewModelTests.swift:5-23`) and `FakeNotifications` (`ReminderCoordinatorTests.swift:5-13`), both actors; see Q4/Q5. `Flag` helper (`SessionRunViewModelTests.swift:25-28`).
- UserDefaults isolation only in `StoreBackupTests.swift:19,48,73` (`UserDefaults(suiteName: "StoreBackupTests-<uuid>")`); temp dirs via `makeStoreDir()` (`:5-10`).
- Coverage by file: Archive (5 tests), CalendarMapping (4), ClientDetailViewModel (2, static helpers only), ClientRepository (5), ExerciseRepository (2), ExportReminder (4), NotificationScheduling (6, pure), PhoneNumber (4), Recording (3), ReminderCoordinator (1), Reporting (5), Scheduling (6), SeedImporter (2), SessionRepository (10), SessionRunViewModel (1), StoreBackup (3), WeightFormatter (3), WorkoutRepository (4).
- **Zero test references:** `EventKitCalendarService`, `LocalNotificationService`, `AppLock`, `ReportExporter`/`ReportPage`, `MessageComposeView`, `ReminderCoordinator.requestAuthorization`/`exportReminderIsDue`; view models `ScheduleViewModel`, `ClientListViewModel`, `ClientEditViewModel`, `ClientReportViewModel`, `ExerciseListViewModel`, `WorkoutListViewModel`, `WorkoutBuilderViewModel`; all views including `TrainMeApp`, `AppBootstrap`, `RecoveryView`, `RootView`, `LockGateView`, `SettingsView`, `SessionEditView`; repository methods `setEventIdentifierForSeries`, `ExerciseRepository.createAll` (direct), `ExerciseRepository.update`. `SessionRunViewModel` is tested only via `delete()`; `load`, `saveNotes`, `record`, `deleteSet`, `setStatus` are not. No UI test target exists.

## Cross-Cutting Observations
- **Default-argument service injection.** `SessionEditView.init` and `SessionRunViewModel.init` default `calendar` to `EventKitCalendarService()`; `RootView.init` constructs `LocalNotificationService()` directly. Protocols `CalendarSyncing`, `NotificationScheduling`, `DataArchiving`, and `*Repository` exist for every service, and tests inject fakes through the same initializers.
- **One actor per feature closure.** `RootView.swift:41-59` creates a new `@ModelActor` (and `ModelContext`) per tab closure from the shared container; `DataArchiveActor` is one of these.
- **`save() async -> Bool` + `errorMessage` is the established edit-form contract** (four forms). List-loading view models uniformly use `(try? ...) ?? []`.
- **Boolean-collapsed authorization.** Both `requestAccess` and `requestAuthorization` fold thrown errors into `false`; only EventKit's status is ever read afterwards (`CalendarService.swift:54,69`), and only inside `push`/`update`.
- **No logging anywhere.** No `Logger`, `os_log`, or `print` in `Sources/`.
- **Three disconnected version numbers** (Q1 table). Only the archive version is enforced.
- **Single-save import, no snapshot.** Atomicity of replace-import rests on one `modelContext.save()`; `StoreBackup` is launch-only.
- **Generated project.** `*.xcodeproj` is ignored; any CI would need `xcodegen generate` first. The only documented destination is a simulator named "iPhone 17".

## Open Areas
- Whether a `@ModelActor`'s `modelContext` has `autosaveEnabled` on by default, and therefore whether staged changes from a failed import could persist on a later save, cannot be determined from the repository.
- Whether `modelContext.delete(model:)` executes immediately against the store or stages until `save()` is likewise a SwiftData runtime detail not visible in the code.
- The README's `iPhone 17` simulator destination was not verified against installed runtimes (no builds were run).
- The commit "Confirm destructive actions, surface failed saves" (1fb8f81) was not diffed; the surfacing inventory in Q3 reflects current code only.
