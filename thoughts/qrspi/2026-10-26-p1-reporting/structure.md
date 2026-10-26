# Structure Outline

## Approach

Grow the single `ReportingQueries` actor one query at a time, each landing with its
UI and tests. Land the `ProgressPoint` shape change first because everything else
builds on it, split the screen second so later phases have a home, then add the
overview features and finish with export. Every phase leaves `main` shippable.

Test command for every phase (CI's destination; run `xcodegen generate` first if
`TrainMe.xcodeproj` is missing):

```
xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

---

## Phase 1: Total-reps chart and optional weight metrics

Make `progression` keep reps-only sets, add a reps series, and show a third chart on
the existing screen. Bodyweight exercises become chartable.

**Files**: `Sources/Persistence/ReportingQueries.swift`,
`Sources/Features/Reports/ClientReportView.swift`,
`Sources/Features/Reports/ClientReportViewModel.swift`,
`Sources/Services/ReportExporter.swift`, `Tests/ReportingTests.swift`

**Key changes**:
- `ProgressPoint { date: Date; topSetWeight: Double?; est1RM: Double?; totalReps: Int }` — modified; `==` still ignores `id`
- `static let minimumPoints = 2` on `ProgressPoint` — new; replaces the two literals
- `progression(clientId:exerciseId:)` — keeps sets where `weight != nil || reps != nil`; `totalReps = Σ reps` per day; weight metrics nil when no weighted set that day
- `ExerciseProgressChart(points:, personalBest:, metric: KeyPath<ProgressPoint, Double?>, unitLabel:)` — modified; filters nil before plotting and before the "not enough data" check
- Third `Section("Total reps")` using `\.totalReps` via a `Double?` bridge
- `ClientReportViewModel.hasEnoughData` — reads `minimumPoints` over weighted points
- Tests: existing assertions move to `compactMap(\.topSetWeight)`; new `totalRepsSumsAcrossSets`, `repsOnlySetsProduceRepsPointWithoutWeight`

**Verify**: tests pass; on device a push-up exercise (reps, no weight) shows the reps
chart and "Not enough data yet" on the two weight charts.

---

## Phase 2: Exercise detail screen with history list

Create `ExerciseReportView` holding the PB callout, three charts, history list and the
existing PDF share. `ClientReportView` becomes a plain list of exercises linking into
it. The picker is removed.

**Files**: new `Sources/Features/Reports/ExerciseReportView.swift`,
new `Sources/Features/Reports/ExerciseReportViewModel.swift`,
`Sources/Persistence/ReportingQueries.swift`,
`Sources/Features/Reports/ClientReportView.swift`,
`Sources/Features/Reports/ClientReportViewModel.swift`,
`Sources/Features/Clients/ClientDetailView.swift`, `Tests/ReportingTests.swift`

**Key changes**:
- `SessionHistoryEntry { id: UUID (instance); sessionStart: Date; sets: [SetRecordDTO] }` — new, `Sendable, Identifiable, Equatable`
- `historyBySession(clientId:exerciseId:) -> [SessionHistoryEntry]` — new on protocol and actor; groups `history` by `workoutInstanceId`, dated from the owning `Session.startAt`, newest first, sets by `setIndex`
- `ExerciseReportViewModel(reporting:, client:, exercise: ExerciseDTO)` with `points`, `personalBest`, `history`, `errorMessage`; `load()` logs via `Log.ui` and sets `errorMessage` on failure
- `ExerciseReportView` — sections: error row, PB, three charts, "History" rows `"<date>  185 lb × 5, 190 lb × 3"`; toolbar `ShareLink` and `.onDisappear` sweep move here
- `ClientReportViewModel` — drops `selectedExerciseId`, `points`, `personalBest`, `loadChart()`; keeps `exercisesWithData` and gains `errorMessage`
- `ClientReportView` — rows `NavigationLink(exercise.name)` → `ExerciseReportView(viewModel: ExerciseReportViewModel(...))`
- `ClientDetailView:44` link text → "View progress"
- Tests: `historyGroupsBySessionNewestFirst`, `historyKeepsTwoSessionsOnOneDayDistinct`

**Verify**: tests pass; on device the overview lists exercises, tapping one shows PB,
charts, history rows and the PDF share; back navigation sweeps `tmp/Reports`.

---

## Phase 3: Consistency with window picker

Add the consistency query and the overview's window picker and consistency section.

**Files**: `Sources/Persistence/ReportingQueries.swift`,
`Sources/Features/Reports/ClientReportView.swift`,
`Sources/Features/Reports/ClientReportViewModel.swift`, `Tests/ReportingTests.swift`

**Key changes**:
- `enum ReportWindow: CaseIterable { fourWeeks, twelveWeeks, all; func start(from now: Date, calendar: Calendar) -> Date? }` — new, in `ReportingQueries.swift`
- `ConsistencySummary { completed: Int; cancelled: Int; noShow: Int; unresolved: Int; var rate: Double? }` — new; `rate` nil when resolved count is 0
- `consistency(clientId:, from: Date?, to: Date) -> ConsistencySummary` — new; fetches `Session` by `clientId` and `startAt` range, buckets by `status`; `unresolved` = `.scheduled && startAt < to`
- `ClientReportViewModel.window: ReportWindow = .twelveWeeks`, `consistency: ConsistencySummary?`; `load()` reloads on window change
- Overview sections: segmented `Picker` bound to `window`; "Consistency" showing `rate` as percent plus the three counts and an "N unresolved" line when non-zero
- Tests: `consistencyRateCountsResolvedOnly`, `consistencyIgnoresFutureScheduled`, `consistencyRespectsWindowStart`

**Verify**: tests pass; on device a client with 3 completed, 1 cancelled, 1 forgotten
past session shows 75 % and "1 unresolved"; switching to 4 weeks changes the counts.

---

## Phase 4: Weekly volume chart and session volume list

Add volume queries and the overview's bar chart plus per-session volume rows.

**Files**: `Sources/Persistence/ReportingQueries.swift`,
`Sources/Features/Reports/ClientReportView.swift`,
`Sources/Features/Reports/ClientReportViewModel.swift`,
`Sources/Support/WeightFormatter.swift`, `Tests/ReportingTests.swift`,
`Tests/WeightFormatterTests.swift`

**Key changes**:
- `VolumeTotals { byUnit: [Unit: Double] }` — new, `Sendable, Equatable`; `isEmpty`
- `SessionVolume { id: UUID (session); start: Date; totals: VolumeTotals }` — new
- `WeeklyVolume { id: Date (week start); totals: VolumeTotals }` — new
- `sessionVolumes(clientId:, from:, to:) -> [SessionVolume]` — new; `Σ weight×reps` over sets with both, keyed by the exercise's `defaultUnit` (exercises fetched once into `[UUID: Unit]`), newest first
- `weeklyVolumes(clientId:, from:, to:) -> [WeeklyVolume]` — new; groups session volumes by `calendar.dateInterval(of: .weekOfYear, for:)?.start`, ascending
- `WeightFormatter.volumeString(_ totals: VolumeTotals) -> String` — new; `"12,450 lb · 300 kg"`, zero units omitted, `"—"` when empty
- `VolumeChart(weeks: [WeeklyVolume])` — new view; `BarMark` per week, one series per unit, `.chartYAxisLabel`
- Overview sections: "Weekly volume" chart (or "Not enough data yet" under two weeks); "Sessions" rows `"<date>  12,450 lb"`
- Tests: `sessionVolumeSumsWeightTimesReps`, `volumeKeepsUnitsSeparate`, `weeklyVolumeGroupsByCalendarWeek` (dates pinned via `DateComponents` mid-week), formatter `volumeStringOmitsZeroUnits`

**Verify**: tests pass; on device a client with lb and kg exercises shows two bar
series and session rows with both figures.

---

## Phase 5: Top exercises ranking

Replace the plain exercise list with a ranked summary carrying PB or best reps.

**Files**: `Sources/Persistence/ReportingQueries.swift`,
`Sources/Features/Reports/ClientReportView.swift`,
`Sources/Features/Reports/ClientReportViewModel.swift`, `Tests/ReportingTests.swift`

**Key changes**:
- `ExerciseSummary { id: UUID (exercise); sessionCount: Int; lastPerformed: Date; bestWeight: Double?; bestTotalReps: Int? }` — new
- `topExercises(clientId:) -> [ExerciseSummary]` — new; distinct completed sessions per `exerciseId`, sorted by count desc then `lastPerformed` desc; `bestTotalReps` is the max per-session rep sum
- `ClientReportViewModel.topExercises: [(ExerciseSummary, ExerciseDTO)]` replaces `exercisesWithData`; name lookup from `exerciseRepo.all()`
- Overview "Top exercises" rows: name, "N sessions", PB via `WeightFormatter.string` or "best N reps" or "no weight recorded"
- Tests: `topExercisesRankBySessionCountThenRecency`, `topExercisesReportBestRepsForUnweighted`

**Verify**: tests pass; on device the most-trained exercise is first and a bodyweight
exercise shows "best N reps".

---

## Phase 6: PNG export, overview page, surfaced render errors

Generalize the exporter, add an overview page, offer PDF and PNG on both screens, and
surface failures.

**Files**: `Sources/Services/ReportExporter.swift`,
`Sources/Features/Reports/ClientReportView.swift`,
`Sources/Features/Reports/ExerciseReportView.swift`, both view models,
new `Tests/ReportExporterTests.swift`

**Key changes**:
- `ReportExporter.render(_ page: some View, baseName: String) throws -> ReportFiles` — new; `ReportFiles { pdf: URL; png: URL }`; PDF path as today, PNG via `ImageRenderer.uiImage` at `scale = 3` and `pngData()`; both get `.complete` protection
- `renderPDF(...)` — removed; `ReportPage` renamed `ExerciseReportPage` and extended with the 1RM and reps charts; new `ClientOverviewPage(clientName:, window:, consistency:, weeks:, topExercises:)` at the same 612×792 frame
- Each view: `@State private var files: ReportFiles?`, `exportError: String?`; a toolbar `Menu("Share")` with `ShareLink("Share PDF", item:)` and `ShareLink("Share PNG", item:)`; render after load, log through `Log.ui` and set `exportError` on throw; error shown as a list row
- Tests: `renderWritesPdfAndPng` (files exist, PNG data non-empty, directory swept on re-render), `sanitizedNameStripsPathCharacters`

**Verify**: tests pass; on device both screens share a PDF and a PNG that match the
screen; a forced failure (unwritable directory in a debug build) shows the error row.

---

## Phase 7: Device verification and backlog close-out

Run the full flow on madphone, then record results and update `BACKLOG.md` rows 1–4,
9, 10 and close issues #3, #4, #5, #6, #11, #12 from the PR.

**Files**: `BACKLOG.md`, `thoughts/qrspi/2026-10-26-p1-reporting/plan.md`

**Verify**: CI green; device checklist recorded in `plan.md`.

---

## Testing Checkpoints

| After | True |
|---|---|
| Phase 1 | `ReportingTests` green with optional weights; reps chart visible on the old screen |
| Phase 2 | Two screens; `historyBySession` tested; PDF share works from the exercise screen |
| Phase 3 | Overview shows window picker and consistency; `consistency` tested for unresolved and window edges |
| Phase 4 | Weekly bar chart and session rows; volume tested per unit and per week |
| Phase 5 | Overview list is ranked with PB/reps; ranking tested |
| Phase 6 | Share menu offers PDF and PNG on both screens; `ReportExporterTests` green; render errors visible |
| Phase 7 | Device-verified; backlog and issues updated |

Phases 3, 4 and 5 are independent of each other and could be reordered; 1 → 2 and
2 → 6 are hard dependencies.
