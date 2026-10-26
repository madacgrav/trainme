# Research Questions

## Context
Focus on the per-client reporting path in the TrainMe iOS app: the reporting queries
and progress computations in `Sources/Persistence/ReportingQueries.swift`, the report
screen and view model in `Sources/Features/Reports/`, the exporter in
`Sources/Services/ReportExporter.swift`, and the session, set-record, exercise and
client models in `Sources/Models/` that feed them. Also look at `ClientDetailView` and
`ClientDetailViewModel`, the unit and weight-formatting helpers in `Sources/Support/`,
and the tests in `Tests/` that cover these areas.

## Questions
1. How does `SwiftDataReportingQueries` load and filter set records for a client and exercise, what do `history`, `progression`, `personalBest` and `exercisesWithData` each return, and how do they treat session status (scheduled, completed, cancelled, no-show) and the `ProgressPoint` per-day aggregation?
2. What is the exact shape of the `Session`, `WorkoutEntry` and `SetRecord` models and their relationships: which fields record date, status, weight, unit, reps and ordering, how are set records linked back to their session and exercise, and is there anything that distinguishes a scheduled session from one that was actually run?
3. How does `ClientReportView` and `ClientReportViewModel` structure the screen today: how is the exercise selected, how is chart data loaded, how is the Epley 1RM chart (`ExerciseProgressChart`) built with Swift Charts, and how are the "not enough data yet" and empty states decided and rendered?
4. How does `ReportExporter` render a report: what SwiftUI content does it compose for `ImageRenderer`, how does it produce the PDF file and where does it write it, how is the file handed to `ShareLink`, and how are render failures and cleanup (`removeReports`) handled in `ClientReportView`?
5. How are weights and units represented and formatted across the app: what does `Unit` on `Exercise` mean for a recorded set, what does `WeightFormatter` do, where is the `defaultWeightUnit` setting read, and is there any existing conversion between lb and kg when sets for one exercise use different units?
6. How does `ClientDetailView` and `ClientDetailViewModel` present a client's sessions today (`splitSessions`, `recentLimit`, upcoming vs past), and how does navigation flow from the client list into the detail screen and on to the report screen and session run screen?
7. What do the existing tests in `Tests/ReportingTests.swift`, `Tests/ClientDetailViewModelTests.swift` and `Tests/WeightFormatterTests.swift` set up and assert, how do they build in-memory SwiftData fixtures for clients, sessions and set records, and what helper patterns do other test files use for seeding sessions with different statuses and dates?
