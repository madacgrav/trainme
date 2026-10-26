# Design Discussion

## Current State

Reporting is a single per-exercise screen fed by one actor.

- `ReportingQueries` (`Sources/Persistence/ReportingQueries.swift:27-35`) has four methods:
  `history`, `progression`, `personalBest`, `exercisesWithData`. All go through
  `completedSetRecords(clientId:)` (`:77-91`), which fetches sessions with
  `statusRaw == "completed"` and then `SetRecord`s whose `workoutInstanceId` is in those
  sessions' instances. Cancelled, no-show and scheduled sessions never reach reporting.
- `progression` drops nil-weight sets, groups by `Calendar.current.startOfDay`, and
  emits one `ProgressPoint(date, topSetWeight, est1RM)` per day (`:47-61`). There is no
  reps series, no volume, no consistency, no client-level summary.
- `ClientReportView` (`Sources/Features/Reports/ClientReportView.swift:11-63`) is a
  `List` with an exercise `Picker`, a PB row, and two `ExerciseProgressChart`s keyed by
  `KeyPath<ProgressPoint, Double>`. The "fewer than two points" threshold is a literal in
  the chart (`:107`) and again in `ClientReportViewModel.hasEnoughData` (`:22`).
- `ReportExporter.renderPDF` (`Sources/Services/ReportExporter.swift:5-47`) takes
  precomputed points/PB/unit, renders a fixed 612×792 `ReportPage` (`:66-104`) through
  `ImageRenderer.render` into a CGContext PDF under `tmp/Reports`, and wipes that folder
  before every render and on screen disappear (`:49-55`). PDF only; the page shows only
  the top-set chart. The call site uses `try?` and nothing is logged on failure
  (`ClientReportView.swift:90`).
- `SetRecord` has no unit and no relationships (`Sources/Models/SetRecord.swift:4-17`).
  Unit is resolved at display time from `Exercise.defaultUnit`
  (`Sources/Models/Exercise.swift:40,67`), and `WeightFormatter.label` maps every
  non-kg unit to "lb" (`Sources/Support/WeightFormatter.swift:12-17`). No conversion
  exists anywhere.
- `Session.statusRaw` is the only run marker; there is no completed-at timestamp
  (`Sources/Models/Session.swift:22-65`). `SessionRepository.forClient` returns all
  statuses newest-first (`Sources/Persistence/SessionRepository.swift:174-181`).
- `ClientDetailView` reaches the report through one `NavigationLink("View progress
  charts")` that builds `ClientReportViewModel(reporting:, exerciseRepo:, client:)`
  inline (`Sources/Features/Clients/ClientDetailView.swift:44-50`). `sessionRepo` is not
  passed down.
- Tests: `Tests/ReportingTests.swift` seeds sessions through the repository actors with
  an `addSession(env, daysAgo:, weight:, reps:, status:)` helper (`:23-51`). Nothing
  tests `ReportExporter`, `ReportPage` or `ClientReportViewModel`.

## Desired End State

Two screens replace the one picker-driven screen.

**Client overview** (the existing `ClientReportView`, reworked):
- A window picker: last 4 weeks / last 12 weeks / all time (default 12 weeks). It drives
  consistency and the volume chart. Top exercises are always all-time.
- Consistency: `completed ÷ (completed + cancelled + noShow)` for sessions whose
  `startAt` falls in the window and before now, shown as a percentage with the three
  counts. Past sessions still `scheduled` are excluded from the rate and shown as an
  "N unresolved" line so the trainer can tidy them.
- Weekly volume: a bar chart of `Σ(weight × reps)` per calendar week, split by unit.
  Below it, completed sessions in the window newest-first with their session volume.
  Totals are per unit (lb and kg side by side); a unit with zero total is hidden.
- Top exercises: exercises ranked by the number of completed sessions they appear in,
  ties broken by most recent, with PB weight (or best total reps for unweighted
  exercises). Each row navigates to the exercise screen.
- Empty state unchanged: "No completed sessions yet".

**Exercise detail** (new `ExerciseReportView`):
- PB callout, top-set chart, Epley 1RM chart, and a new total-reps chart. Each chart
  shows "Not enough data yet" independently when it has fewer than two points.
- History list: one row per completed session the exercise appears in, newest first,
  showing the date and the sets as "185 lb × 5, 185 lb × 5, 190 lb × 3".

**Export**: both screens offer a Share menu with "Share PDF" and "Share PNG" of the page
currently shown. The PNG is the same page rendered at 3× scale. Render failures are
logged and surfaced as a one-line message instead of silently hiding the button.

**Verification**: unit tests for every new query (volume by unit, weekly grouping,
consistency with unresolved sessions, top-exercise ranking, reps progression,
history grouping), a PNG/PDF render test, and a device check on madphone that both
screens, both exports and the empty states behave.

## Patterns to Follow

- **Query placement**: add methods to the `ReportingQueries` protocol and implement them
  in `SwiftDataReportingQueries` (`ReportingQueries.swift:27-39`). It already owns a
  `modelContext` and can fetch `Session` and `Exercise` directly, so the overview view
  model does not need `sessionRepo`. Keep everything completed-only via
  `completedSetRecords`.
- **Day and week grouping**: use `Calendar.current` and `startOfDay`, as `progression`
  does (`:50-51`); weeks via `calendar.dateInterval(of: .weekOfYear, for:)?.start`.
- **Value types**: new result structs follow `ProgressPoint` (`:4-20`): `Sendable`,
  `Identifiable`, `Equatable` with `==` ignoring the generated `id`.
- **Units**: resolve from `Exercise.defaultUnit` and format with `WeightFormatter`
  (`WeightFormatter.swift:6-8`). Never convert. Volume totals are keyed by `Unit`.
- **View model shape**: `@MainActor @Observable final class` with constructor-injected
  dependencies, as `ClientReportViewModel` (`ClientReportViewModel.swift:4-20`).
- **Failure surfacing**: follow `ClientDetailViewModel.reload` (log through
  `Sources/Support/Log.swift`, set an `errorMessage` shown as the first list row,
  `ClientDetailView.swift:10-14`) rather than the bare `try?` in
  `ClientReportViewModel.load/loadChart` (`:25-26,40-41`). Do not follow the latter.
- **Charts**: reuse `ExerciseProgressChart`'s shape (`ClientReportView.swift:100-142`):
  `LineMark` with `.monotone` and `.circle`, `.chartYAxisLabel`, height 220. Move the
  "fewer than two points" threshold into one named constant and drop the duplicate in
  `hasEnoughData`.
- **Navigation and DI**: build the exercise view model inline in the `NavigationLink`
  destination, as `ClientDetailView.swift:44-50` does for the report.
- **Exporter**: keep `ReportExporter` data-in, URL-out (`ReportExporter.swift:5-13`).
  Generalize the render entry point to take any page view and a base filename, keep the
  `tmp/Reports` sweep (`:27,49-55`), `.complete` file protection (`:45`) and
  `sanitized` names (`:59-62`). Keep the `.onDisappear` sweep in both screens.
- **Tests**: Swift Testing, per-file `Env` + `makeEnv()` over
  `PersistenceController.makeContainer(inMemory: true)`, sessions created `.scheduled`
  then `setStatus` (`Tests/ReportingTests.swift:5-51`). Extend `addSession` with a
  `date:` parameter so week boundaries can be pinned with `DateComponents`, as
  `Tests/SessionRepositoryTests.swift:79-80` does.

## Design Decisions

1. **Consistency ignores unresolved sessions** — rate = completed ÷ (completed +
   cancelled + noShow) over sessions with `startAt` in the window and in the past.
   Past-but-still-scheduled sessions are reported as a separate unresolved count. The
   app never prompts to resolve a session, so counting them as missed would punish the
   trainer for the app's own gap.
2. **Volume is per unit, never converted** — `Σ(weight × reps)` over sets with both
   values, grouped by the exercise's `defaultUnit`, returned as `[Unit: Double]` and
   displayed as separate lb/kg figures. Matches the Settings promise that weights are
   never converted and avoids inventing a conversion factor.
3. **Overview plus drill-down** — the picker-driven screen becomes a client overview;
   a new `ExerciseReportView` holds the per-exercise charts and history. The top-exercises
   list is the navigation into it. The existing `ClientDetailView` link text becomes
   "View progress".
4. **Export what is on screen** — each screen renders its own page (an overview page
   and an exercise page) to PDF and PNG. No multi-page bundle. PNG uses
   `ImageRenderer.uiImage` at scale 3 and `pngData()`.
5. **Total reps joins `ProgressPoint`** — `progression` keeps sets that have a weight or
   reps, `topSetWeight` and `est1RM` become optional, and a `totalReps: Int` is added.
   Charts take a `KeyPath<ProgressPoint, Double?>` and skip points lacking that metric.
   This makes bodyweight exercises chartable without a second query.
6. **History groups by session, not by day** — rows come from `history` grouped by
   `workoutInstanceId`, dated by the session's `startAt`, sets ordered by `setIndex`.
   Two sessions on one day stay distinct.
7. **Top exercises rank by session count** — distinct completed sessions containing the
   exercise, descending; tie-break on most recent `performedAt`. Simple, explainable,
   and independent of units.
8. **Render errors are surfaced** — exporter failures are logged and set an
   `exportError` shown in the list, closing the "swallowed PDF render" note from
   `BACKLOG.md`.
9. **Window picker is shared state on the overview view model** — one `enum Window`
   (`.fourWeeks`, `.twelveWeeks`, `.all`) feeds both consistency and volume so the two
   always agree.

## What We're NOT Doing

- No lb↔kg conversion and no unit stored on `SetRecord`.
- No schema change: `SchemaV1` stays at eight models; no new `VersionedSchema`.
- No "mark as completed" prompt for unresolved sessions; they are only counted.
- No changes to `ScheduleView`, `SessionRunView`, the session row, or the client detail
  session lists beyond the link label.
- No multi-page PDF, no combined client report, no CSV (BACKLOG row 11).
- No RPE in the history list (`rpe` is always nil, BACKLOG row 13).
- No chart interaction (selection, tooltips) or axis styling beyond what exists.
- No changes to the other open P1 rows (series calendar, week view, inline exercise
  create, archived clients).

## Open Risks

- **Optional weight fields ripple**: making `topSetWeight`/`est1RM` optional touches
  `ExerciseProgressChart`, `ReportPage`, `ReportingTests` assertions and the PB marker.
  The structure phase should sequence this before the new charts.
- **`Calendar.current` week start** depends on locale (Sunday vs Monday). Tests must
  pin dates far from week boundaries or construct the expected week start with the same
  calendar call.
- **Main-actor render cost** doubles (PDF and PNG) on every load and window change.
  If it is noticeable on device, render lazily when the Share menu opens instead.
- **`ImageRenderer` in unit tests**: the exporter test runs on the simulator main
  actor; if `uiImage` returns nil headlessly the test should assert on the PDF path and
  record the PNG as device-verified.
- **Exercises with data but no reps and no weight** (duration-only) still appear in
  `exercisesWithData`. They will show in top exercises with no PB; the row should
  degrade to "no weight recorded" rather than hide.
- **Overview query volume**: volume and consistency fetch all of a client's completed
  sessions and sets each load. Fine at trainer scale; noted in case it shows on device.
