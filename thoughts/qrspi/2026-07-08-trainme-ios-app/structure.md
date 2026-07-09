# Structure Outline

## Approach

Build TrainMe as vertical slices, each crossing the full stack: `@Model` →
`@ModelActor` repository (protocol-typed, exchanging Sendable DTOs) → `@Observable`
view model → SwiftUI view. Phase 0 stands up the XcodeGen project + SwiftData
container + one thin end-to-end slice so the build/test/simulator loop is proven
before feature work. Each later phase adds one feature end-to-end with its own Swift
Testing coverage (in-memory `ModelContainer`) plus a simulator smoke check. Build
commands use the `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` prefix.

Convention per entity: `Models/<Entity>.swift` (`@Model`), `Models/DTO/<Entity>DTO.swift`
(Sendable Codable struct + mapping), `Persistence/<Entity>Repository.swift` (protocol +
`@ModelActor` impl), `Features/<Feature>/…ViewModel.swift` + `…View.swift`.

---

## Phase 0: Project skeleton + container + "Hello client" slice

Stand up the buildable app: XcodeGen spec, Swift `.gitignore`, `ModelContainer`
wiring, a repository base, and one trivial slice (list hard-coded → persisted clients)
to prove the whole loop compiles, tests, and launches.

**Files**: `project.yml`, `.gitignore` (replace Java one), `Sources/TrainMeApp.swift`,
`Sources/Persistence/PersistenceController.swift`, `Sources/Models/Client.swift`,
`Sources/Models/DTO/ClientDTO.swift`, `Sources/Persistence/ClientRepository.swift`,
`Sources/Features/Clients/ClientListView.swift` + `ClientListViewModel.swift`,
`Tests/ClientRepositoryTests.swift`, `Info.plist`.
**Key changes**:
- `@Model final class Client { @Attribute(.unique) var id: UUID; var name: String; var createdAt/updatedAt: Date; … }`
- `struct ClientDTO: Codable, Sendable, Identifiable { let id: UUID; var name: String; … }` + `init(from:)`/`toModel()` mapping
- `protocol ClientRepository: Sendable { func all() async throws -> [ClientDTO]; func upsert(_:) async throws; func delete(id: UUID) async throws }`
- `@ModelActor actor SwiftDataClientRepository: ClientRepository`
- `func makeContainer(inMemory: Bool = false) throws -> ModelContainer`

**Verify**: `DEVELOPER_DIR=… xcodebuild test -scheme TrainMe -destination 'platform=iOS
Simulator,name=iPhone 17'` passes (repo upsert/fetch round-trip); app launches on
simulator and shows an empty client list.

---

## Phase 1: Client management (P0)

Full client CRUD + roster search + client detail scaffold, with expanded fields (goal,
injuries, notes), archive instead of delete.

**Files**: extend `Client`/`ClientDTO`/`ClientRepository`; `Features/Clients/`
(`ClientListView`, `ClientEditView`, `ClientDetailView` + view models);
`Tests/ClientRepositoryTests.swift`.
**Key changes**:
- `Client` fields: `phoneE164: String`, `goal: String?`, `injuries: String?`, `notes: String?`, `isArchived: Bool`
- `func search(_ query: String) async throws -> [ClientDTO]`, `func setArchived(id: UUID, _:Bool) async throws`
- phone normalization helper `normalizeE164(_:) -> String?`

**Verify**: tests cover create/edit/search/archive; manually add a client, edit fields,
search the roster, archive and confirm it leaves the active list.

---

## Phase 2: Exercise library + seed (P0)

Canonical exercise library with category/metrics, autocomplete-ready search, and a
small bundled seed (~25–35) imported once on first launch.

**Files**: `Models/Exercise.swift` + DTO + `ExerciseRepository`; `Resources/seed_exercises.json`;
`Persistence/SeedImporter.swift`; `Features/Exercises/` (`ExerciseListView`,
`ExerciseEditView` + VMs); `Tests/ExerciseRepositoryTests.swift`, `SeedImporterTests.swift`.
**Key changes**:
- `@Model Exercise { id: UUID; name; category: ExerciseCategory; metrics: MetricSet; defaultUnit: Unit; … }`
- `enum ExerciseCategory: String, Codable { strength, cardio, bodyweight, mobility }`; `OptionSet MetricSet` (weight/reps/sets/duration/distance)
- `func search(prefix:) async throws -> [ExerciseDTO]`, `func create(_:) async throws -> ExerciseDTO`
- `func seedIfEmpty() async throws` (guards on empty store; runs via `Task.detached`)

**Verify**: tests confirm seed loads once and is idempotent; search returns prefix
matches. Manually: first launch shows seeded exercises; add a custom exercise; search
finds both.

---

## Phase 3: Workout builder (P0)

Create/edit/duplicate/delete workout templates as ordered exercise entries with target
params. Reordering (P1) included.

**Files**: `Models/Workout.swift`, `Models/WorkoutEntry.swift` + DTOs + `WorkoutRepository`;
`Features/Workouts/` (`WorkoutListView`, `WorkoutBuilderView` + VMs, exercise-picker
using Phase 2 search); `Tests/WorkoutRepositoryTests.swift`.
**Key changes**:
- `@Model Workout { id; name; @Relationship(deleteRule: .cascade) entries: [WorkoutEntry]; … }`
- `@Model WorkoutEntry { id; exerciseId: UUID; order: Int; targetSets/reps/weight/duration: …?; }`
- `func duplicate(id: UUID) async throws -> WorkoutDTO`, `func reorder(workoutId:, entryIds:[UUID]) async throws`
- DTO mapping preserves entry order; use `append(contentsOf:)` (never looped append)

**Verify**: tests build a template, duplicate it (deep copy, new UUIDs), reorder
entries. Manually: build "Leg Day A" with target params, duplicate, edit the copy,
confirm original unchanged.

---

## Phase 4: Scheduling + calendar (P0, recurring P1)

Schedule a session for a client on a date/time, attach workout(s) as **instances**
(template copy per `decisions.md`), calendar day/week view, recurring series.

**Files**: `Models/Session.swift`, `Models/WorkoutInstance.swift`, `Models/RecurrenceRule.swift`
+ DTOs + `SessionRepository`; `Features/Schedule/` (`CalendarView`, `SessionEditView` + VMs);
`Tests/SessionRepositoryTests.swift`, `SchedulingTests.swift`.
**Key changes**:
- `@Model Session { id; clientId: UUID; startAt/endAt: Date; status: SessionStatus; notes; @Relationship(.cascade) instances: [WorkoutInstance]; seriesId: UUID?; eventIdentifier: String? }`
- `enum SessionStatus { scheduled, completed, cancelled, noShow }`
- `@Model WorkoutInstance { id; sourceWorkoutId: UUID; plannedEntries: [PlannedEntry]; … }` (copied from template at schedule time)
- `func schedule(_ dto: SessionDTO) async throws`, `func expandRecurrence(_ rule: AppRecurrence, from:to:) -> [Date]`
- `struct AppRecurrence: Codable, Sendable { frequency; interval; weekdays:[Int]; end:… }`

**Verify**: tests confirm scheduling copies the template (editing template afterward
doesn't change the instance); recurrence expands "Tue/Thu" correctly. Manually: create
a session, see it on the calendar, create a recurring series. *(No EventKit yet — see
Phase 7. No double-booking detection — out of scope.)*

---

## Phase 5: Run / record a session (P0)

Open a scheduled session, record actual `SetRecord`s against planned instance, fast
entry (steppers, repeat-last-set), set status.

**Files**: `Models/SetRecord.swift` + DTO; extend `SessionRepository`;
`Features/Session/` (`SessionRunView`, `SetEntryView` + VM); `Tests/RecordingTests.swift`.
**Key changes**:
- `@Model SetRecord { id; workoutInstanceId: UUID; exerciseId: UUID; setIndex: Int; weight/reps/duration/distance:…?; rpe: Double?; }`
- `func recordSet(_:) async throws`, `func setStatus(sessionId:, _: SessionStatus) async throws`
- metric-driven input: recording UI reads `exercise.metrics` to show only relevant fields

**Verify**: tests record sets and complete a session. Manually: run a session, log sets
with steppers + repeat-last, mark completed, confirm saved to history.

---

## Phase 6: History + progression reporting (P0/P1)

Per-client and per-exercise history; Swift Charts progression (top-set weight, est.
1RM/reps over time) with personal-best callout and sparse-data guard.

**Files**: `Persistence/ReportingQueries.swift` (read-only aggregates on repositories);
`Features/Reports/` (`ClientReportView`, `ExerciseProgressChart` + VM);
`Tests/ReportingTests.swift`.
**Key changes**:
- `func history(clientId:, exerciseId:) async throws -> [SetRecordDTO]`
- `struct ProgressPoint: Sendable { date: Date; topSetWeight: Double; est1RM: Double }`; `func progression(clientId:, exerciseId:) async throws -> [ProgressPoint]`
- chart guards `points.count < 2` → placeholder; `RuleMark`/`PointMark` + `.annotation` for PB; completed-only, cancelled/no-show excluded

**Verify**: tests assert aggregates exclude cancelled sessions and PB is correct;
2-point exercises flagged. Manually: chart shows progression across recorded sessions,
PB marker appears, thin data shows "not enough data yet."

---

## Phase 7a: Reminders — local notifications + client texts (P0)

Trainer local notifications (24h/1h, nearest-N budget) and tap-to-send client
reminder texts.

**Files**: `Services/NotificationService.swift`, `Services/MessagingService.swift`
(+ `MessageComposeView: UIViewControllerRepresentable`); wire `reschedule` into
`SessionRepository` mutations; `Tests/NotificationSchedulingTests.swift`.
**Key changes**:
- `protocol NotificationScheduling { func reschedule(upcoming: [SessionDTO]) async }` (respects 64 cap, nearest-N)
- `func composeText(to: String, body: String)` via `MFMessageComposeViewController`

**Verify**: tests assert nearest-N scheduling stays ≤64. Manually (simulator/device):
notification fires before a session; "Text reminder" opens prefilled Messages sheet.

---

## Phase 7b: Calendar push + report sharing (P1)

One-way EventKit push to default calendar (incl. recurrence) and PDF report via the
share sheet.

**Files**: `Services/CalendarService.swift`, `Services/ReportExporter.swift`; wire
push/remove into `SessionRepository` schedule/cancel; Info.plist keys.
**Key changes**:
- `protocol CalendarSyncing { func push(_: SessionDTO) async throws -> String; func remove(eventId: String) async throws }` (full access, stores `eventIdentifier`, `EKRecurrenceRule` from `AppRecurrence`)
- `func renderReport(_:) -> URL` (PDF), presented via `.fileExporter`/`ShareLink`
- Info.plist: `NSCalendarsFullAccessUsageDescription` (+ `NSFaceIDUsageDescription` staged for P8)

**Verify**: recurrence→`EKRecurrenceRule` mapping unit-tested. Manually: session
appears in system calendar; cancelling removes it; report shares as PDF via Gmail/
Messages from the share sheet.

---

## Phase 8: Export / import + biometric lock (P0)

Versioned JSON export/import (merge vs replace) via Files/share sheet; biometric app
lock on launch; periodic export prompt + onboarding data-loss notice.

**Files**: `Services/DataArchive.swift` (Codable envelope), `Features/Settings/`
(export/import UI), `Services/AppLock.swift` + `LockGateView`; `Tests/ArchiveRoundTripTests.swift`.
**Key changes**:
- `struct ArchiveEnvelope: Codable { schemaVersion: Int; exportedAt: Date; clients/exercises/workouts/sessions/setRecords: [...DTO] }`
- `func export() async throws -> URL`, `func `import`(url:, mode: ImportMode) async throws`; `enum ImportMode { merge, replace }` (merge = upsert by id)
- `AppLock`: `evaluatePolicy(.deviceOwnerAuthentication)`, gated on `scenePhase`, lock on `.background`

**Verify**: round-trip test — export → wipe in-memory store → import → identical object
graph; `schemaVersion` mismatch rejected gracefully. Manually: export to Files,
reimport (merge and replace); app requires Face ID on foreground.

---

## Testing Checkpoints

- **After P0**: project builds, `xcodebuild test` green, app launches on iPhone 17 sim.
- **After P1–P3**: repositories round-trip; clients, exercises (seeded + custom), and
  workout templates persist and are editable; duplication deep-copies.
- **After P4–P5**: sessions schedule with template-copied instances, recurrence
  expands, sets record, status transitions; template edits don't leak into instances.
- **After P6**: charts render from completed-session data; PB + sparse-data guard work.
- **After P7a**: notifications ≤64 and fire; compose sheets prefill.
- **After P7b**: calendar push/remove + report share function on simulator/device.
- **After P8**: export/import round-trips losslessly; biometric gate locks/unlocks.
- **Resume aid**: each phase's tests are self-contained against an in-memory container,
  so a context reset can re-verify any completed phase by running its test file.

## Slicing note

Phases 7a/7b are the least unit-testable — `MFMessageCompose…`, EventKit writes, and
notification delivery need a simulator/device and can't be fully asserted in Swift
Testing. Their logic (nearest-N budget, recurrence mapping, report rendering) is
unit-tested; the OS-mediated send/display steps are manual checkpoints.
