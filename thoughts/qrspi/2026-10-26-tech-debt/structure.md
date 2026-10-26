# Structure Outline

## Approach
Seven vertical slices, one per backlog issue cluster, ordered so each leaves `main`
shippable: scaffolding and CI first so every later slice runs under it, then persistence
(schema, import safety), then the two permission-gated services, then the remaining
error-surfacing sweep, then backlog bookkeeping. Each slice ships its own tests.

Test command for every phase (from README):
`xcodegen generate && xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' test`

---

## Phase 1: Scaffolding — CI, manifests, logger (#27)
Adds the files the project is missing and the `Logger` every later phase uses. After this,
pull requests run the test suite automatically.

**Files**: `.github/workflows/ci.yml` (new), `Sources/PrivacyInfo.xcprivacy` (new),
`Sources/TrainMe.entitlements` (new), `Sources/Support/Log.swift` (new), `project.yml`,
`README.md`
**Key changes**:
- `ci.yml`: on `push` to `main` + `pull_request`; `runs-on: macos-26`; steps checkout →
  `brew install xcodegen` → `xcodegen generate` → `xcodebuild … CODE_SIGNING_ALLOWED=NO test`
- `PrivacyInfo.xcprivacy`: `NSPrivacyTracking=false`, `NSPrivacyCollectedDataTypes=[]`,
  `NSPrivacyAccessedAPITypes=[{UserDefaults, reasons:[CA92.1]}]`
- `project.yml`: `CODE_SIGN_ENTITLEMENTS: Sources/TrainMe.entitlements`; add `.xcprivacy`
  to app `resources`
- `enum Log { static let persistence, archive, calendar, notifications, ui: Logger }` — new,
  subsystem `com.madacgrav.trainme`

**Verify**: test command passes locally; `xcodebuild -showBuildSettings | grep ENTITLEMENTS`
shows the file; built `.app` contains `PrivacyInfo.xcprivacy`; first PR shows a green check.

---

## Phase 2: Versioned schema and schema-keyed backup (#22)
The container opens through a migration plan, and the pre-open backup fires on schema
version change instead of marketing version.

**Files**: `Sources/Persistence/SchemaV1.swift` (new), `Sources/Persistence/PersistenceController.swift`,
`Sources/Persistence/StoreBackup.swift`, `Sources/TrainMeApp.swift`,
`Tests/StoreBackupTests.swift`, `Tests/SchemaTests.swift` (new)
**Key changes**:
- `enum SchemaV1: VersionedSchema { static let versionIdentifier = Schema.Version(1,0,0); static var models: [any PersistentModel.Type] }` — new
- `enum TrainMeMigrationPlan: SchemaMigrationPlan { schemas = [SchemaV1.self]; stages = [] }` — new
- `PersistenceController.makeContainer(inMemory:)` → `ModelContainer(for: Schema(versionedSchema: SchemaV1.self), migrationPlan: TrainMeMigrationPlan.self, configurations:)`; `schemaTypes` becomes `SchemaV1.models`
- `StoreBackup.versionKey = "lastRunSchemaVersion"`; `legacyVersionKey = "lastRunAppVersion"`
- `StoreBackup.backupIfVersionChanged(storeURL:currentVersion:defaults:)` — reads legacy key
  once when new key is absent, removes it; backup dir `pre-schema-<version>/`
- `AppBootstrap.init` passes `SchemaV1.versionIdentifier.description`

**Verify**: test command passes; new tests: legacy key migrates without a spurious backup,
schema-version change triggers backup, `SchemaV1.models` count == 8. Manual: install over
the existing build on madphone (export first) and confirm data intact and no backup dir created.

---

## Phase 3: Safe replace-import with snapshot and rollback (#23, #29)
A failed replace-import leaves the store exactly as it was and tells the user so.

**Files**: `Sources/Services/Archive/SafeImporter.swift` (new),
`Sources/Services/Archive/DataArchive.swift`, `Sources/Features/Settings/SettingsView.swift`,
`Tests/SafeImporterTests.swift` (new), `Tests/ArchiveRoundTripTests.swift`
**Key changes**:
- `protocol DataArchiving` gains `func rollback() async` — new requirement
- `DataArchiveActor.importData` wraps delete/upsert/save in `do/catch { modelContext.rollback(); Log.archive.error(…); throw }`
- `struct SafeImporter { init(archive: any DataArchiving, snapshotURL: URL); func importReplacing(url: URL) async throws(ImportOutcome) }` — new
- `enum ImportOutcome: Error { case failedAndRestored(underlying: Error), failedAndRestoreFailed(underlying: Error, restore: Error) }` — new
- `ArchiveError` gains `case decodeFailed` (wraps `DecodingError` from the full decode)
- `SettingsView.runImport(mode:)` uses `SafeImporter` for `.replace`; distinct `statusMessage`
  per `ArchiveError` case and per `ImportOutcome` case; export failure sets a message
- Snapshot at `applicationSupportDirectory/pre-import.json`, `.completeFileProtection`,
  deleted on success and in `AppBootstrap.init`

**Verify**: test command passes; new tests: replace into non-empty store removes locals;
throwing fake archive → snapshot re-imported and `.failedAndRestored` thrown;
`importArchive(url:)` with missing file → `.unreadable`; valid probe + malformed body →
`.decodeFailed`. Manual: import a truncated JSON in replace mode on device → data unchanged,
"restored" message shown.

---

## Phase 4: Notification authorization gate and Permissions row (#25)
Alerts are only scheduled when authorized, and Settings shows the notification status with
an Open Settings link.

**Files**: `Sources/Services/NotificationService.swift`, `Sources/Services/ReminderCoordinator.swift`,
`Sources/Features/Settings/SettingsView.swift`, `Sources/RootView.swift`,
`Tests/ReminderCoordinatorTests.swift`, `Tests/NotificationServiceTests.swift` (new)
**Key changes**:
- `protocol NotificationScheduling` gains `func authorizationStatus() async -> UNAuthorizationStatus`
- `LocalNotificationService.reschedule` — removes stale `sess-` requests, then
  `guard status == .authorized || status == .provisional else { return }`; `center.add`
  errors logged via `Log.notifications`
- `ReminderCoordinator.notificationStatus: UNAuthorizationStatus` — new observable property,
  refreshed in `refresh()` and after `requestAuthorization()`
- `SettingsView` gains `init(archive:reminders:)` and a "Permissions" `Section` with a
  `PermissionRow(title:status:)` view and `Link("Open Settings", destination: openSettingsURL)`
- `RootView.swift:59` passes `reminders` into `SettingsView`
- `FakeNotifications` gains `var status: UNAuthorizationStatus` and `addFailures` recording

**Verify**: test command passes; new tests: denied status → `reschedule` called but no
adds recorded; authorized → adds recorded; coordinator exposes status. Manual: deny
notifications on device → Settings row reads Denied, Open Settings works; allow → Allowed.

---

## Phase 5: Calendar fallback, typed error, and non-blocking calendar warnings (#26, part of #24)
A missing default calendar no longer silently drops the event; calendar failures after a
successful save are reported without blocking; stored identifiers are never overwritten
with nil on failure.

**Files**: `Sources/Services/CalendarService.swift`, `Sources/Features/Schedule/SessionEditView.swift`,
`Sources/Features/Schedule/EventIdentifierResolution.swift` (new),
`Sources/Features/Settings/SettingsView.swift`, `Tests/SessionRunViewModelTests.swift`,
`Tests/EventIdentifierResolutionTests.swift` (new), `Tests/CalendarServiceTests.swift` (new)
**Key changes**:
- `enum CalendarError: Error { case noWritableCalendar }` — new
- `protocol CalendarSyncing` gains `func authorizationStatus() async -> EKAuthorizationStatus`
- `EventKitCalendarService.push` — `calendar = defaultCalendarForNewEvents ?? firstWritableCalendar() ?? throw .noWritableCalendar`
- `enum CalendarOutcome { case unchanged, set(String), cleared, failed(Error) }` — new
- `func resolveEventIdentifier(existing: String?, wantsCalendar: Bool, result: Result<String?, Error>) -> CalendarOutcome` — new pure function replacing `SessionEditView.swift:244-255` logic
- `SessionEditView.calendarWarning: String?`; `onSaved: (String?) -> Void` carries the warning;
  callers in `ScheduleView` and `SessionRunView` show a brief `.alert`
- `SettingsView` Permissions section gains the Calendar row
- `FakeCalendar` gains `var pushResult: Result<String?, Error>`, `var updateResult`, `var removeShouldThrow`

**Verify**: test command passes; new tests: `resolveEventIdentifier` for all four outcomes
including failed-update keeps existing id; fake push throwing → `calendarWarning` set and
save still returns true. Manual: with no calendars writable on device, save a session →
session saved, warning shown; with a calendar → event created.

---

## Phase 6: Error-state sweep on run screen, root, and settings (#24, #28 partial)
Every remaining swallowed mutation either surfaces or logs; SessionRunViewModel gets
error state and test coverage.

**Files**: `Sources/Features/Session/SessionRunViewModel.swift`, `Sources/Features/Session/SessionRunView.swift`,
`Sources/RootView.swift`, `Sources/Features/Settings/SettingsView.swift`,
`Sources/Features/Workouts/WorkoutListViewModel.swift`, `Sources/Features/Clients/ClientDetailViewModel.swift`,
`Tests/SessionRunViewModelTests.swift`
**Key changes**:
- `SessionRunViewModel.errorMessage: String?` — new; `delete() async -> Bool`;
  `setStatus`, `record`, `deleteSet`, `saveNotes` → `do/catch` setting `errorMessage` +
  `Log.ui.error`; `setStatus` clears event id only when `remove` succeeded
- `SessionRunView` renders `errorMessage` section; dismisses only on `delete() == true`
- `RootView.seedFailed: Bool` → `.alert("Couldn't load the exercise library")`;
  `SeedImporter` failure logged
- `WorkoutListViewModel.duplicate/delete`, `ClientDetailViewModel.setArchived` → logged `do/catch`
- Remaining list-load `try?` sites get `Log.*.debug` only

**Verify**: test command passes; new tests: failing `delete` → returns false, `errorMessage`
set; failing `setStatus` → message set, event id untouched; `record` failure → sets list
unchanged. Manual: none beyond smoke on device. `grep -c 'try?' Sources` drops to list
loads plus the five file-system cleanups.

---

## Phase 7: Backlog and docs bookkeeping
**Files**: `BACKLOG.md`, `README.md`
**Key changes**: strike rows 20–27 or move to a "Done" table with PR link; README gains a
CI badge and a "Permissions" note; close issues #22–#29 on merge.
**Verify**: links resolve; `gh issue list` shows them closed after merge.

---

## Testing Checkpoints
| After | True |
|---|---|
| 1 | CI runs the suite on PRs; `Log` compiles; manifest + entitlements in the bundle |
| 2 | Store opens via `SchemaV1`; backup keyed on schema version; device data intact |
| 3 | Replace-import is atomic from the user's view; four new import tests pass |
| 4 | No notification adds when denied; Settings shows notification status |
| 5 | Calendar nil default handled; no nil-overwrite of identifiers; calendar warning shown |
| 6 | `SessionRunViewModel` has error state and tests; seed/export failures visible |
| 7 | BACKLOG and issues reflect the work |

Phases 4 and 5 are independent of each other and of 3; 6 depends on 1 (logger) and 5
(warning plumbing in `SessionRunView`). Phase 2 should be verified on device before 3 lands.
