# Research Findings

All paths are relative to the repo root. `Sources/` is the app target, `Tests/` the
Swift Testing target (`project.yml:25-33`).

## Q1: How does `SwiftDataReportingQueries` load and filter set records, what do `history`, `progression`, `personalBest` and `exercisesWithData` return, and how do they treat session status and the per-day aggregation?

### Findings
- Protocol `ReportingQueries: Sendable` (`Sources/Persistence/ReportingQueries.swift:27-35`) has four `async throws` methods: `history(clientId:exerciseId:) -> [SetRecordDTO]`, `progression(clientId:exerciseId:) -> [ProgressPoint]`, `personalBest(clientId:exerciseId:) -> SetRecordDTO?`, `exercisesWithData(clientId:) -> [UUID]`.
- Implementation is `@ModelActor actor SwiftDataReportingQueries` (`:38-39`), constructed with `modelContainer:` in `Sources/RootView.swift:46`.
- All four methods funnel through private `completedSetRecords(clientId:)` (`:77-91`):
  1. Fetch `Session` where `clientId == clientId && statusRaw == "completed"` (`:79-83`).
  2. Flatten `session.instances.map(\.id)` to `instanceIds` (`:84`); return `[]` if empty (`:85`).
  3. Fetch `SetRecord` where `instanceIds.contains($0.workoutInstanceId)` (`:86-90`).
  - The join from set record to session is by UUID (`SetRecord.workoutInstanceId` → `WorkoutInstance.id`), not a relationship traversal. The `exerciseId` filter is not in the predicate; callers filter in memory.
- Session status: only `.completed` is included. `scheduled`, `cancelled` and `noShow` are excluded from every method (comment at `:75-76` cites PRD §8). No method compares `performedAt` against the session window.
- `history` (`:40-45`): filters `exerciseId`, sorts `performedAt` ascending, maps to `SetRecordDTO`. Records with nil `weight` are kept.
- `progression` (`:47-61`): takes `history`, drops nil-weight records (`:49`), groups by `Calendar.current.startOfDay(for: performedAt)` (`:50-51`), one `ProgressPoint` per day with `topSetWeight = max weight` (`:56`) and `est1RM = max over sets of epley1RM(weight, reps)` (`:57`), sorted by date ascending (`:60`). `Calendar.current` is the device calendar; no explicit time zone.
- `personalBest` (`:63-67`): `history` filtered to non-nil weight, `.max` by weight only. No tie-break, reps not considered.
- `exercisesWithData` (`:69-71`): `Array(Set(records.map(\.exerciseId)))`, unordered, not filtered on weight (duration-only sets count).
- `ProgressPoint` (`:4-20`): `Sendable, Identifiable, Equatable` with `id: UUID` (fresh per init, `:11`), `date`, `topSetWeight`, `est1RM`. Custom `==` ignores `id` (`:17-19`).
- `epley1RM(weight:reps:)` is a free function: `weight * (1 + Double(reps ?? 0) / 30)` (`:22-25`).
- Sibling query not in `ReportingQueries`: `SessionRepository.completedCount(since:)` (`Sources/Persistence/SessionRepository.swift:240-246`) counts sessions with `statusRaw == completed && updatedAt > floor` across all clients. Used by the export reminder, not by reports.

## Q2: What is the exact shape of `Session`, workout-entry and `SetRecord` models and their relationships, and what distinguishes a scheduled session from one that was run?

### Findings
- `SessionStatus: String, Codable, Sendable, CaseIterable` with cases `scheduled, completed, cancelled, noShow`; raw values are the case names (`Sources/Models/Session.swift:4-6`).
- `AppRecurrence` (`Session.swift:10-20`): `frequency` (`daily`/`weekly`), `interval`, `weekdays: [Int]` (1=Sun…7=Sat), `endDate?`, `occurrenceCount?`. Stored on `Session.recurrenceData: Data?`.
- `Session` (`Session.swift:22-65`): `id` (unique), `clientId: UUID` (plain, no relationship to `Client`), `startAt`, `endAt`, `statusRaw: String` (default `"scheduled"`), `notes?`, `@Relationship(deleteRule: .cascade, inverse: \WorkoutInstance.session) instances: [WorkoutInstance]`, `seriesId?`, `recurrenceData?`, `eventIdentifier?`, `createdAt`, `updatedAt`. Computed `status` falls back to `.scheduled` (`:64`).
- `WorkoutInstance` (`Session.swift:67-81`): `id`, `sourceWorkoutId: UUID` (plain back-reference), `name` (copied from template), `@Relationship(.cascade, inverse: \PlannedEntry.instance) plannedEntries`, `session: Session?`.
- `PlannedEntry` (`Session.swift:83-111`): `id`, `exerciseId`, `order`, `targetSets?`, `targetReps?`, `targetWeight?`, `targetDuration?`, `instance?`. A session therefore **snapshots** the workout into instance + planned entries; nothing links back to `Workout`/`WorkoutEntry` by relationship.
- `Workout` / `WorkoutEntry` (`Sources/Models/Workout.swift:4-49`) mirror the template side: `WorkoutEntry` has the same target fields plus `order` and `workout: Workout?`.
- `SetRecord` (`Sources/Models/SetRecord.swift:4-17`): `id`, `workoutInstanceId: UUID`, `exerciseId: UUID`, `setIndex: Int`, `weight: Double?`, `reps: Int?`, `duration: Int?`, `distance: Double?`, `rpe: Double?`, `performedAt: Date` (defaults `.now`, `:29`), `createdAt`, `updatedAt`. **No `@Relationship` and no unit field.** Not covered by any cascade delete; `SessionRepository.delete` removes them explicitly by `instanceIds` (`SessionRepository.swift:232-234`).
- Linkage chain: `SetRecord.workoutInstanceId` → `WorkoutInstance.id` → `WorkoutInstance.session`. `SetRecord.exerciseId` matches `Exercise.id`; no link to `PlannedEntry`.
- Scheduled vs run: `statusRaw` is the only marker. No `completedAt`/`startedAt`/`finishedAt` field exists (grep of `Sources`). `startAt`/`endAt` are the scheduled window; `updatedAt` changes on status set. Per-set evidence is `SetRecord.performedAt`.
- `Client` (`Sources/Models/Client.swift:4-38`) and `Exercise` (`Sources/Models/Exercise.swift:34-68`) have no relationships. `Exercise` stores `categoryRaw`, `metricsRaw: Int` (bit set `weight, reps, sets, duration, distance`), `defaultUnitRaw`, `isCustom`.
- `SchemaV1.models` lists all eight: `Client, Exercise, Workout, WorkoutEntry, Session, WorkoutInstance, PlannedEntry, SetRecord` (`Sources/Persistence/SchemaV1.swift:9-10`); migration plan has one schema and no stages (`:19-22`).
- `SetRecordDTO` (`Sources/Models/DTO/SetRecordDTO.swift:3-16`) has the same twelve fields; `init(_ model:)` at `:19`.
- Session repository queries available today (`SessionRepository.swift:7-42`): `sessions(from:to:)`, `upcoming(after:limit:)` (scheduled only, `:164-172`), `forClient(_:)` (all statuses, `startAt` descending, `:174-181`), `completedCount(since:)`, `setsFor(instanceId:)`, `lastSet(clientId:exerciseId:)` (`:273-286`, `performedAt` descending, limit 1).

## Q3: How do `ClientReportView` and `ClientReportViewModel` structure the screen, select the exercise, load chart data, build the Epley chart, and render empty states?

### Findings
- `ClientReportViewModel` is `@MainActor @Observable final class` (`Sources/Features/Reports/ClientReportViewModel.swift:4-6`) holding `reporting: any ReportingQueries`, `exerciseRepo: any ExerciseRepository`, `client: ClientDTO` (`:7-9`) and observable `exercisesWithData: [ExerciseDTO]`, `selectedExerciseId: UUID?`, `points: [ProgressPoint]`, `personalBest: SetRecordDTO?` (`:11-14`).
- `load()` (`:24-32`): `ids = Set(reporting.exercisesWithData)`, `all = exerciseRepo.all()`, `exercisesWithData = all.filter { ids.contains($0.id) }` (repository order), default `selectedExerciseId = first?.id` if nil, then `loadChart()`. Both fetches use `try?` and fall back to empty.
- `loadChart()` (`:34-42`): nil selection clears `points`/`personalBest`; otherwise two sequential `try?` awaits for `progression` and `personalBest`.
- `hasEnoughData` is `points.count >= 2` (`:22`), used only by the PDF guard.
- View (`Sources/Features/Reports/ClientReportView.swift`): `@State var viewModel` (`:5`); `selectedUnit` is the selected exercise's `defaultUnit ?? .lb` (`:7-9`); body is one `List` (`:12`).
  - Empty branch when `exercisesWithData.isEmpty`: `ContentUnavailableView("No completed sessions yet", …)` (`:13-18`).
  - Section 1: `Picker("Exercise", selection: $viewModel.selectedExerciseId)` over `exercisesWithData`, tags `UUID?.some(id)` (`:20-26`).
  - Section 2: personal best, shown only if `personalBest?.weight` is non-nil: `LabeledContent("Personal best")` with `WeightFormatter.string(weight, unit: selectedUnit)` (`:28-35`). No date shown on screen.
  - Section 3 `"Top-set weight"`: `ExerciseProgressChart(points:, personalBest:, metric: \.topSetWeight, unitLabel:)` (`:37-44`).
  - Section 4 `"Estimated 1RM (Epley)"`: same struct with `personalBest: nil`, `metric: \.est1RM` (`:45-52`).
  - Title `"\(client.name) — Progress"` inline (`:55-56`); toolbar `ShareLink(item: pdfURL)` only when `pdfURL != nil` (`:57-63`).
  - `.task { await viewModel.load(); renderPDF() }` (`:64-67`); `.onChange(of: selectedExerciseId) { Task { await loadChart(); renderPDF() } }` (`:68-73`); `.onDisappear` clears `pdfURL` and calls `removeReports()` (`:74-78`).
- `ExerciseProgressChart` (`ClientReportView.swift:100-142`): inputs `points`, `personalBest`, `metric: KeyPath<ProgressPoint, Double>`, `unitLabel` (`:101-104`).
  - If `points.count < 2` (literal, `:107`) renders `ContentUnavailableView("Not enough data yet", systemImage: "chart.xyaxis.line", description: "Record this exercise in at least two completed sessions.")` at height 180 (`:108-113`).
  - Otherwise `Chart { ForEach(points) { LineMark(x: .value("Date", date, unit: .day), y: .value("Weight", point[keyPath: metric])).interpolationMethod(.monotone).symbol(.circle) } }` (`:115-123`), plus an orange `PointMark` with `"PB"` annotation at `startOfDay(pb.performedAt)` / `pb.weight` when `personalBest` has a weight (`:124-135`).
  - `.chartYAxisLabel(unitLabel)` (`:137`), `.frame(height: 220)` (`:138`). No explicit axis marks.
- A point is one calendar day, so the two-point threshold means two distinct days with weighted sets. An exercise can be in the picker (via a duration-only set) yet show "Not enough data yet" in both charts.

## Q4: How does `ReportExporter` render a report, produce the PDF, hand it to `ShareLink`, and handle failures and cleanup?

### Findings
- `enum ReportExporter` with `@MainActor static func renderPDF(clientName:exerciseName:points:personalBest:unit:) throws -> URL` (`Sources/Services/ReportExporter.swift:5-13`). It takes precomputed data; it never calls `ReportingQueries`.
- `ReportPage: View` (`:66-104`) is the composed content: `VStack(alignment: .leading, spacing: 16)` with title "TrainMe Progress Report" (`:75-76`), client name (`:77-78`), exercise name (`:79-81`), optional "Personal best: <weight> on <date>" (`:83-86`), `ExerciseProgressChart(metric: \.topSetWeight)` (`:88-93`), "Generated <now>" caption (`:95-97`), `Spacer()`. Modifiers `.padding(32)`, `.frame(width: 612, height: 792, alignment: .topLeading)`, `.background(.white)` (`:100-102`). The 1RM chart is not included. `ReportPage` has no other call site (grep of `Sources`).
- Rendering (`:21-47`): `ImageRenderer(content:)` with `proposedSize = 612×792` (`:22`), no `scale` set. `renderer.render { size, renderIn in … }` opens `CGContext(url as CFURL, mediaBox:&, nil)`; nil context sets `renderError = CocoaError(.fileWriteUnknown)`; otherwise `beginPDFPage` / `renderIn(context)` / `endPDFPage` / `closePDF` (`:33-43`). Single page. Then `if let renderError { throw }` (`:44`) and `setAttributes([.protectionKey: .complete])` (`:45`). `UIKit` is imported (`:2`) but `UIGraphicsPDFRenderer` is not used.
- Location: `reportsDirectory = temporaryDirectory/Reports` (`:49-50`). `renderPDF` calls `removeReports()` first (`:27`) then `createDirectory` (`:28`). Filename `"\(sanitized(clientName)) — \(sanitized(exerciseName)) Progress.pdf"` (`:29-30`); `sanitized` maps `/` and `:` to `-` and trims (`:59-62`).
- `removeReports()` is `try? removeItem(at: reportsDirectory)` (`:52-55`). Called at render start and from `ClientReportView.onDisappear` (`ClientReportView.swift:74-78`, comment: rendered reports hold client PII).
- Call site `ClientReportView.renderPDF()` (`:83-96`): guards `viewModel.hasEnoughData` and a matching exercise, else `pdfURL = nil`; then `pdfURL = try? ReportExporter.renderPDF(…)`. Any throw becomes nil with no log and no UI message; the share button simply does not appear. The render runs synchronously on the main actor after every load and selection change.
- Handoff: `ShareLink(item: pdfURL)` with the file URL directly (`:58-60`).

## Q5: How are weights and units represented, formatted and converted?

### Findings
- `enum Unit: String, Codable, Sendable, CaseIterable { lb, kg, mi, km, min, sec }` (`Sources/Models/Exercise.swift:8-10`). One enum spans weight, distance and time.
- `Exercise.defaultUnitRaw: String = "lb"` (`:40`); computed `defaultUnit` falls back to `.lb` (`:67`). `ExerciseDTO.defaultUnit: Unit` (`Sources/Models/DTO/ExerciseDTO.swift:8`) serializes as the raw string.
- `SetRecord` / `SetRecordDTO` store **no unit** (`SetRecord.swift:6-17`, `SetRecordDTO.swift:3-16`). Every display site looks up the exercise's *current* `defaultUnit` by `exerciseId`. If the exercise unit is edited later, stored weights are relabelled, not rewritten (`ExerciseRepository.swift:56` updates only `defaultUnitRaw`).
- `WeightFormatter` (`Sources/Support/WeightFormatter.swift`): header says the exercise's `defaultUnit` is the unit of record and nothing is converted (`:3-4`). `string(_:unit:)` = `"\(value.formatted()) \(label(unit))"` (`:6-8`); `label` returns `"kg"` for `.kg` and `"lb"` for every other case including `mi`/`sec` (`:12-17`); `stepIncrement` = 2.5 for kg, else 5 (`:19-21`).
- `defaultWeightUnit` readers: `SettingsView.swift:15` (`@AppStorage`, default `"lb"`, segmented lb/kg picker `:52-62`, footer "Existing weights are never converted") and `ExerciseEditView.swift:32-33` (reads `UserDefaults` directly, falls back `.lb`, seeds only *new* exercises). No other readers.
- Conversion: grep for `2.2046|0.4536|convert|kilogram|pound` finds only the two comment/string lines above. No lb↔kg conversion exists.
- Set-recording screen: `SetEntryView.weightUnit = exercise?.defaultUnit ?? .lb` (`SessionRunView.swift:270`), label `"Weight (\(label))"` (`:278`), ± step buttons clamped at 0 (`:280-282`). Distance uses the raw unit string with `"mi"` fallback (`:305`); duration is hard-labelled seconds (`:296-300`). `record` passes `weight` only when `metrics.contains(.weight)` (`:332-343`); `SessionRunViewModel.record` builds the DTO with `rpe: nil`, `setIndex = max + 1` (`SessionRunViewModel.swift:115-142`).
- Seed data (`Sources/Resources/seed_exercises.json`) assigns `lb` to lifts and bodyweight, `sec`/`min` to timed work, `mi`/`km` to distance.
- Other unit consumers: `ClientReportView.swift:7-9,31,42,50,95`; `ReportExporter.swift:84,92`; `WorkoutBuilderViewModel.swift:34,49` and `WorkoutBuilderView.swift:36,80,98,163`.

## Q6: How do `ClientDetailView` and `ClientDetailViewModel` present sessions, and how does navigation flow from list to detail to report and session run?

### Findings
- `ClientDetailViewModel` (`Sources/Features/Clients/ClientDetailViewModel.swift`) holds `repository`, `exerciseRepo`, `sessionRepo`, `reporting`, `reminders`, `client` (`:7-12,21-35`), plus `upcomingSessions` and `recentSessions` (`:13-16`). `static let recentLimit = 10` (`:19`).
- `reload()` (`:37-58`): refresh client via `allIncludingArchived`, `sessionRepo.forClient(id)` (newest first; logs and uses `[]` on error), `splitSessions(all, now: .now)`, then `reminders.refresh()`.
- `splitSessions` (`:61-70`) is pure static: `upcoming` = `status == .scheduled && startAt > now` sorted ascending, unlimited; `recent` = everything else sorted descending, `.prefix(recentLimit)`.
- `ClientDetailView` sections in order: error text (`:10-14`), "Contact" (`:15-26`), "Upcoming Sessions" (`:27-34`), "Recent Sessions" (`:35-42`), "Progress Reports" with `NavigationLink("View progress charts")` (`:43-51`), archived banner (`:52-57`). Toolbar menu Edit/Archive (`:60-72`); `.task { reload() }` (`:95`).
- Rows: `sessionLink` (`:98-113`) renders `SessionRow(session:, clientName: startAt.formatted(date: .abbreviated, time: .omitted))`, i.e. the date is passed in the `clientName` slot. `SessionRow` (`Sources/Features/Schedule/ScheduleView.swift:94-130`) shows that string, start–end times, instance names joined by ", ", and a status icon only (green check / grey x / orange person-x; nothing for scheduled).
- Navigation chain: `RootView.swift:41-48` builds `ClientListViewModel(repo:, exerciseRepo:, sessionRepo:, reporting: SwiftDataReportingQueries(modelContainer:), reminders:)`; `ClientListView` wraps a `NavigationStack` (`ClientListView.swift:8`) and each row links to `ClientDetailView(viewModel: ClientDetailViewModel(… all five deps …, client:))` (`:10-18`).
- Detail → report: `ClientReportView(viewModel: ClientReportViewModel(reporting:, exerciseRepo:, client:))` built inline in the destination closure (`ClientDetailView.swift:44-50`). `sessionRepo` is not passed to the report view model.
- Detail → run: `SessionRunView(viewModel: SessionRunViewModel(sessionRepo:, exerciseRepo:, clientRepo:, session:, clientName:, clientPhone:, clientInjuries:, onStatusChanged: { reload() }))` (`:99-109`); `workoutRepo` is not passed (`SessionRunView.swift:5-7` documents this), calendar defaults to `EventKitCalendarService()` (`SessionRunViewModel.swift:33`).
- Schedule path for comparison (`ScheduleView.swift:41-56`): same `SessionRunView` but with `workoutRepo`, client fields from per-client dictionaries, and `onStatusChanged: { load() }`. `ScheduleViewModel` has no `reporting` dependency (`RootView.swift:30-38`).

## Q7: What do the existing reporting, client-detail and formatter tests set up and assert, and what fixture patterns do other tests use?

### Findings
- Framework: Swift Testing everywhere (`import Testing`, `@Test`, `#expect`, `#require`); no XCTest, no `@Suite`. Some tests are `@Test @MainActor` (`ClientDetailViewModelTests.swift:14,30`; `SessionRunViewModelTests.swift`; `ReminderCoordinatorTests.swift:31,57`).
- Container: every file calls `try PersistenceController.makeContainer(inMemory: true)` itself (factory at `Sources/Persistence/PersistenceController.swift:8-23`, `isStoredInMemoryOnly` at `:17`, `Schema(versionedSchema: SchemaV1.self)` at `:18-22`). No shared `TestSupport` helper; `Tests/` holds only test files plus `Fixtures/export-v1.json`. No test touches `ModelContext` directly; all seeding goes through `SwiftData*Repository(modelContainer:)` actors with DTOs.
- `Tests/ReportingTests.swift`:
  - `Env` (`:5-11`): `sessions`, `workouts`, `reporting`, random `clientId`/`exerciseId`. `makeEnv()` (`:13-20`). No `Client` or `Exercise` row is inserted.
  - `addSession(env, daysAgo:, weight:, reps: = 5, status:)` (`:23-51`): `start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)`, upsert a one-entry `WorkoutDTO`, `schedule(dto, attaching: [template.id])` as `.scheduled`, read `instances.first!.id`, `recordSet` one `SetRecordDTO(performedAt: start)`, then `setStatus(id, status)`.
  - Tests: `progressionExcludesCancelledAndNoShow` (`:53`, expects `[185, 195]`), `personalBestIsHeaviestCompletedSet` (`:65`, expects 225 with a 315 cancelled), `epleyFormula` (`:76`), `sparseDataDetectable` (`:83`, one point), `exercisesWithDataOnlyListsCompleted` (`:92`).
- `Tests/ClientDetailViewModelTests.swift`: pure DTO builder `session(hoursFromNow:status:)` (`:5-12`) with status passed directly (no repo). `splitsUpcomingFromRecent` (`:14`) and `recentIsCapped` (`:30`, 20 sessions → `recentLimit`).
- `Tests/WeightFormatterTests.swift`: `formatsLbAndKg` (`:4`), `nonWeightUnitsFallBackToLb` (`:9`), `stepIncrements` (`:14`).
- Seeding patterns elsewhere:
  - Client: `ClientRepositoryTests.swift:10-16` `dto(id:name:phone:)` then `repo.upsert`.
  - Exercise: only `ArchiveRoundTripTests.swift:37-41` creates a real row via `exercises.create(ExerciseDTO(…defaultUnit: .lb…))`; other files use bare `UUID()`.
  - Workout: `RecordingTests.swift:20-25`.
  - Session: `SessionRepositoryTests.swift:18-25` `sessionDTO(clientId:startAt:)` always `.scheduled`, status changed after via `setStatus` (`:103-106`).
  - Set record: `RecordingTests.swift:38-44` `set(env, index:, weight:, performedAt:)`; instance id always from `sessions.get(id:)!.instances.first!.id`.
- Dates: relative `.now` offsets and `Calendar.current.date(byAdding:)` dominate; `SessionRepositoryTests.swift:79-80,114,130` and `SchedulingTests.swift:5-7` use `DateComponents(year:month:day:hour:)`; `ExportReminderTests.swift:5-6` uses a fixed `Date(timeIntervalSince1970: 1_800_000_000)` with `daysAgo(_:)`. No fixed `TimeZone` or `Calendar(identifier:)` anywhere in `Tests/`. `SessionRepositoryTests.swift:204-206` sleeps 20 ms to separate `updatedAt` values.
- Doubles: `FakeCalendar: CalendarSyncing` and `FailingSessionRepo: SessionRepository` (wraps a real repo, toggles throws) in `SessionRunViewModelTests.swift:7-46,88-141`; `FakeNotifications: NotificationScheduling` in `ReminderCoordinatorTests.swift:6-19`. No doubles exist for `ReportingQueries`, `ExerciseRepository`, `ClientRepository` or `WorkoutRepository`.
- No test file names `ReportExporter`, `ReportPage`, `ClientReportView` or `ClientReportViewModel`.
- Config: `project.yml` sets iOS 26.0, Swift 6.0, `SWIFT_STRICT_CONCURRENCY complete` (`:4-9`); test target `TrainMeTests` depends on `TrainMe`, scheme `TrainMe` tests it (`:25-40`). CI (`.github/workflows/ci.yml:22-27`) runs `xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' … test` on `macos-26`.

## Cross-Cutting Observations
- **Status is the only run marker.** Reporting, upcoming lists, consistency-style counts and the detail split all key off `Session.statusRaw`. There is no timestamp for when a session was marked complete other than `updatedAt`.
- **Set records are UUID-joined, not related.** Every path from a set back to its session goes `workoutInstanceId → WorkoutInstance → session`, and from a set to its exercise by `exerciseId`. The reporting actor does this join by fetching sessions first and then sets by `instanceIds.contains`.
- **Units live on the exercise, not the set.** All weight display resolves `exercise.defaultUnit` at render time; `WeightFormatter.label` collapses every non-kg unit to "lb". `ProgressPoint` and the exporter carry bare `Double`s plus a `Unit` passed separately.
- **One chart struct, two metrics.** `ExerciseProgressChart` is parameterised by a `KeyPath<ProgressPoint, Double>` and is reused by both on-screen sections and the PDF page. The `points.count < 2` threshold is duplicated as a literal in the chart (`ClientReportView.swift:107`) and in `hasEnoughData` (`ClientReportViewModel.swift:22`).
- **Exporter is data-in, URL-out.** `ReportExporter.renderPDF` takes already-loaded points/PB/unit, renders a fixed 612×792 `ReportPage` through `ImageRenderer.render` into a CGContext PDF, and cleans the whole `tmp/Reports` folder before each render and on screen disappear.
- **Error handling in the report path is `try?` throughout**: `load()`, `loadChart()` and `renderPDF()` all swallow errors to empty state or nil URL, with no logging. Elsewhere (`ClientDetailViewModel.reload`) failures are logged and surfaced via `errorMessage`.
- **Dependencies flow by constructor injection** from `RootView` → list VM → detail VM → report/run VMs. The report VM receives `reporting` and `exerciseRepo` only; the run VM receives `sessionRepo`, `exerciseRepo`, `clientRepo`.
- **Test convention**: per-file `Env` struct + `makeEnv()` over an in-memory container, DTO builders with default arguments, status applied via `setStatus` after `schedule`, dates relative to `.now` with `Calendar.current`.

## Open Areas
- Whether `Calendar.current` grouping in `progression` behaves consistently across DST or time-zone changes is not exercised by any test; all tests use the device calendar.
- `ReportPage`'s comment says it is reused by an in-app share preview, but no such preview exists in `Sources`; the comment is stale relative to the code.
- No code path reads `SetRecord.rpe` or `distance` for reporting; `exercisesWithData` includes duration/distance-only exercises, but `progression`/`personalBest` drop them. The resulting on-screen behaviour (picker entry with "Not enough data yet") is inferred from the code, not confirmed on device.
- `ImageRenderer.scale` is never set; what resolution a bitmap render would produce is not determinable from the PDF path alone.
