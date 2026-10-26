# Implementation Plan

## Overview

Replace the single picker-driven report screen with a client overview (window picker,
consistency, weekly volume, top exercises) that drills into a per-exercise screen (PB,
top-set / 1RM / total-reps charts, session history). Both screens export the page on
screen as PDF and PNG. All new computation lives on `ReportingQueries`; nothing is
converted between units; only completed sessions feed progression.

**Test command** (every phase; run `xcodegen generate` first whenever a Swift file is
added or `TrainMe.xcodeproj` is missing):

```bash
xcodegen generate && xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -30
```

**Device build** (madphone, UDID `00008140-001E31AE21DB001C`):

```bash
xcodebuild -project TrainMe.xcodeproj -scheme TrainMe -configuration Debug -destination 'id=00008140-001E31AE21DB001C' -derivedDataPath build/DerivedData -allowProvisioningUpdates build && xcrun devicectl device install app --device 00008140-001E31AE21DB001C build/DerivedData/Build/Products/Debug-iphoneos/TrainMe.app && xcrun devicectl device process launch --device 00008140-001E31AE21DB001C com.madacgrav.trainme
```

Commit once per phase. Branch: `2026-10-26-p1-reporting`.

---

## Phase 1: Total-reps chart and optional weight metrics

### Changes

#### 1. `ProgressPoint` and `progression`
**File**: `Sources/Persistence/ReportingQueries.swift`
**Action**: modify

Replace the `ProgressPoint` struct (lines 4-20):

```swift
struct ProgressPoint: Sendable, Identifiable, Equatable {
    /// Fewer points than this and a chart shows "Not enough data yet".
    static let minimumPoints = 2

    let id: UUID
    let date: Date
    /// nil when no set that day had a weight (e.g. bodyweight work).
    let topSetWeight: Double?
    let est1RM: Double?
    /// Sum of reps across every set that day; 0 when no set recorded reps.
    let totalReps: Int

    init(date: Date, topSetWeight: Double?, est1RM: Double?, totalReps: Int) {
        self.id = UUID()
        self.date = date
        self.topSetWeight = topSetWeight
        self.est1RM = est1RM
        self.totalReps = totalReps
    }

    /// Reps as an optional metric so the chart can treat it like the weight series.
    var totalRepsMetric: Double? { totalReps > 0 ? Double(totalReps) : nil }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date && lhs.topSetWeight == rhs.topSetWeight
            && lhs.est1RM == rhs.est1RM && lhs.totalReps == rhs.totalReps
    }
}
```

Update the protocol doc comment on `progression` to: `/// One point per day: max top-set weight, best Epley est. 1RM (nil without weighted sets) and total reps.`

Replace the `progression` body (lines 47-61):

```swift
func progression(clientId: UUID, exerciseId: UUID) async throws -> [ProgressPoint] {
    let records = try await history(clientId: clientId, exerciseId: exerciseId)
        .filter { $0.weight != nil || $0.reps != nil }
    let calendar = Calendar.current
    let byDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.performedAt) }
    return byDay
        .map { day, sets in
            let weighted = sets.filter { $0.weight != nil }
            return ProgressPoint(
                date: day,
                topSetWeight: weighted.compactMap(\.weight).max(),
                est1RM: weighted.map { epley1RM(weight: $0.weight ?? 0, reps: $0.reps) }.max(),
                totalReps: sets.compactMap(\.reps).reduce(0, +)
            )
        }
        .sorted { $0.date < $1.date }
}
```

`history`, `personalBest`, `exercisesWithData`, `completedSetRecords` unchanged.

#### 2. Chart takes an optional metric
**File**: `Sources/Features/Reports/ClientReportView.swift`
**Action**: modify `ExerciseProgressChart` (lines 100-142)

```swift
struct ExerciseProgressChart: View {
    let points: [ProgressPoint]
    let personalBest: SetRecordDTO?
    let metric: KeyPath<ProgressPoint, Double?>
    let unitLabel: String

    /// Only days that have this metric are plotted and counted.
    private var plotted: [(point: ProgressPoint, value: Double)] {
        points.compactMap { point in point[keyPath: metric].map { (point, $0) } }
    }

    var body: some View {
        if plotted.count < ProgressPoint.minimumPoints {
            ContentUnavailableView(
                "Not enough data yet",
                systemImage: "chart.xyaxis.line",
                description: Text("Record this exercise in at least two completed sessions.")
            )
            .frame(height: 180)
        } else {
            Chart {
                ForEach(plotted, id: \.point.id) { entry in
                    LineMark(
                        x: .value("Date", entry.point.date, unit: .day),
                        y: .value(unitLabel, entry.value)
                    )
                    .interpolationMethod(.monotone)
                    .symbol(.circle)
                }
                if let pb = personalBest, let weight = pb.weight {
                    // PointMark block unchanged
                }
            }
            .chartYAxisLabel(unitLabel)
            .frame(height: 220)
            .padding(.vertical, 4)
        }
    }
}
```

Add a third section after "Estimated 1RM (Epley)" in the `body`:

```swift
Section("Total reps") {
    ExerciseProgressChart(
        points: viewModel.points,
        personalBest: nil,
        metric: \.totalRepsMetric,
        unitLabel: "reps"
    )
}
```

The two existing sections keep `\.topSetWeight` and `\.est1RM`; they now type-check as `Double?` with no edit.

#### 3. View model threshold
**File**: `Sources/Features/Reports/ClientReportViewModel.swift`
**Action**: modify line 22

```swift
var hasEnoughData: Bool {
    points.filter { $0.topSetWeight != nil }.count >= ProgressPoint.minimumPoints
}
```

#### 4. Report page
**File**: `Sources/Services/ReportExporter.swift`
**Action**: no code change; `ReportPage` passes `\.topSetWeight`, which now matches `KeyPath<ProgressPoint, Double?>`. Build to confirm.

#### 5. Tests
**File**: `Tests/ReportingTests.swift`
**Action**: modify

Replace `addSession` with a two-level helper that later phases reuse:

```swift
/// Schedules a session with one instance, records the given sets, applies the status.
/// Returns the session id.
@discardableResult
private func addSession(
    _ env: Env,
    start: Date,
    sets: [(weight: Double?, reps: Int?)],
    status: SessionStatus,
    exerciseId: UUID? = nil
) async throws -> UUID {
    let exerciseId = exerciseId ?? env.exerciseId
    let template = WorkoutDTO(
        id: UUID(), name: "W",
        entries: [WorkoutEntryDTO(id: UUID(), exerciseId: exerciseId, order: 0, targetSets: nil, targetReps: nil, targetWeight: nil, targetDuration: nil)],
        createdAt: .now, updatedAt: .now
    )
    try await env.workouts.upsert(template)
    let dto = SessionDTO(
        id: UUID(), clientId: env.clientId, startAt: start,
        endAt: start.addingTimeInterval(3600), status: .scheduled,
        notes: nil, instances: [], seriesId: nil, recurrence: nil,
        eventIdentifier: nil, createdAt: .now, updatedAt: .now
    )
    try await env.sessions.schedule(dto, attaching: [template.id])
    let instanceId = try await env.sessions.get(id: dto.id)!.instances.first!.id
    for (index, set) in sets.enumerated() {
        try await env.sessions.recordSet(SetRecordDTO(
            id: UUID(), workoutInstanceId: instanceId, exerciseId: exerciseId,
            setIndex: index, weight: set.weight, reps: set.reps, duration: nil, distance: nil,
            rpe: nil, performedAt: start.addingTimeInterval(Double(index) * 60),
            createdAt: .now, updatedAt: .now
        ))
    }
    try await env.sessions.setStatus(id: dto.id, status)
    return dto.id
}

private func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -days, to: .now)!
}

/// One-set convenience used by the original tests.
@discardableResult
private func addSession(
    _ env: Env, daysAgo days: Int, weight: Double?, reps: Int? = 5, status: SessionStatus
) async throws -> UUID {
    try await addSession(env, start: daysAgo(days), sets: [(weight, reps)], status: status)
}
```

Update `progressionExcludesCancelledAndNoShow` line 62 to
`#expect(points.compactMap(\.topSetWeight) == [185, 195])`. Add:

```swift
@Test func totalRepsSumsAcrossSets() async throws {
    let env = try makeEnv()
    try await addSession(env, start: daysAgo(7), sets: [(185, 5), (185, 5), (190, 3)], status: .completed)

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.count == 1)
    #expect(points.first?.totalReps == 13)
    #expect(points.first?.topSetWeight == 190)
}

@Test func repsOnlySetsProduceRepsPointWithoutWeight() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 7, weight: nil, reps: 20, status: .completed)
    try await addSession(env, daysAgo: 3, weight: nil, reps: 25, status: .completed)

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.map(\.totalReps) == [20, 25])
    #expect(points.allSatisfy { $0.topSetWeight == nil && $0.est1RM == nil })
    #expect(points.compactMap(\.totalRepsMetric).count == 2)

    let pb = try await env.reporting.personalBest(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(pb == nil)
}
```

### Verification
#### Automated
- [x] Test command passes; `ReportingTests` shows 7 tests green.
#### Manual
- [x] Device: a client with two completed push-up sessions (reps, no weight) shows a line on "Total reps" and "Not enough data yet" on the two weight charts; no share button (no weighted points).
- [x] Device: a client with two completed squat sessions shows all three charts.

---

## Phase 2: Exercise detail screen with history list

### Changes

#### 1. History grouped by session
**File**: `Sources/Persistence/ReportingQueries.swift`
**Action**: modify

Add after `ProgressPoint`:

```swift
/// Every set of one exercise in one completed session, in set order.
struct SessionHistoryEntry: Sendable, Identifiable, Equatable {
    /// The workout instance id.
    let id: UUID
    let sessionStart: Date
    let sets: [SetRecordDTO]
}
```

Add to the protocol:

```swift
/// Completed-session sets for this exercise grouped by session, newest first.
func historyBySession(clientId: UUID, exerciseId: UUID) async throws -> [SessionHistoryEntry]
```

Split the private fetch so later phases can reuse the pieces; `completedSetRecords`
becomes a composition:

```swift
// MARK: - Private

/// Completed sessions for the client, optionally bounded by startAt.
private func completedSessions(clientId: UUID, from: Date? = nil, to: Date? = nil) throws -> [Session] {
    let completedRaw = SessionStatus.completed.rawValue
    let floor = from ?? .distantPast
    let ceiling = to ?? .distantFuture
    return try modelContext.fetch(
        FetchDescriptor<Session>(
            predicate: #Predicate {
                $0.clientId == clientId && $0.statusRaw == completedRaw
                    && $0.startAt >= floor && $0.startAt < ceiling
            }
        )
    )
}

private func setRecords(forInstanceIds instanceIds: [UUID]) throws -> [SetRecord] {
    guard !instanceIds.isEmpty else { return [] }
    return try modelContext.fetch(
        FetchDescriptor<SetRecord>(
            predicate: #Predicate { instanceIds.contains($0.workoutInstanceId) }
        )
    )
}

/// Set records joined to COMPLETED sessions for the client. Cancelled and
/// no-show sessions are excluded from all reporting (PRD §8 data honesty).
private func completedSetRecords(clientId: UUID) throws -> [SetRecord] {
    let sessions = try completedSessions(clientId: clientId)
    return try setRecords(forInstanceIds: sessions.flatMap { $0.instances.map(\.id) })
}
```

Implement on the actor:

```swift
func historyBySession(clientId: UUID, exerciseId: UUID) async throws -> [SessionHistoryEntry] {
    let sessions = try completedSessions(clientId: clientId)
    var startByInstance: [UUID: Date] = [:]
    for session in sessions {
        for instance in session.instances { startByInstance[instance.id] = session.startAt }
    }
    let records = try setRecords(forInstanceIds: Array(startByInstance.keys))
        .filter { $0.exerciseId == exerciseId }
    return Dictionary(grouping: records, by: \.workoutInstanceId)
        .compactMap { instanceId, sets -> SessionHistoryEntry? in
            guard let start = startByInstance[instanceId] else { return nil }
            return SessionHistoryEntry(
                id: instanceId,
                sessionStart: start,
                sets: sets.sorted { $0.setIndex < $1.setIndex }.map(SetRecordDTO.init)
            )
        }
        .sorted { $0.sessionStart > $1.sessionStart }
}
```

#### 2. Exercise view model
**File**: `Sources/Features/Reports/ExerciseReportViewModel.swift`
**Action**: create

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ExerciseReportViewModel {
    private let reporting: any ReportingQueries
    let client: ClientDTO
    let exercise: ExerciseDTO

    var points: [ProgressPoint] = []
    var personalBest: SetRecordDTO?
    var history: [SessionHistoryEntry] = []
    var errorMessage: String?

    init(reporting: any ReportingQueries, client: ClientDTO, exercise: ExerciseDTO) {
        self.reporting = reporting
        self.client = client
        self.exercise = exercise
    }

    var unit: Unit { exercise.defaultUnit }

    /// Any chart has something to draw, so the page is worth exporting.
    var hasEnoughData: Bool { points.count >= ProgressPoint.minimumPoints }

    func load() async {
        errorMessage = nil
        do {
            points = try await reporting.progression(clientId: client.id, exerciseId: exercise.id)
            personalBest = try await reporting.personalBest(clientId: client.id, exerciseId: exercise.id)
            history = try await reporting.historyBySession(clientId: client.id, exerciseId: exercise.id)
        } catch {
            Log.ui.error("exercise report load failed: \(error.localizedDescription)")
            errorMessage = "Couldn't load progress for this exercise."
        }
    }

    /// "185 lb × 5, 185 lb × 5, 190 lb × 3" — one entry per set, in set order.
    func summary(of sets: [SetRecordDTO]) -> String {
        sets.map { set in
            switch (set.weight, set.reps, set.duration) {
            case let (weight?, reps?, _): "\(WeightFormatter.string(weight, unit: unit)) × \(reps)"
            case let (weight?, nil, _): WeightFormatter.string(weight, unit: unit)
            case let (nil, reps?, _): "\(reps) reps"
            case let (nil, nil, duration?): "\(duration)s"
            default: "—"
            }
        }
        .joined(separator: ", ")
    }
}
```

#### 3. Exercise view
**File**: `Sources/Features/Reports/ExerciseReportView.swift`
**Action**: create. Moves the PB section, three chart sections, PDF share, `renderPDF()` and
`.onDisappear` sweep out of `ClientReportView`, adds the error row and history.

```swift
import Charts
import SwiftUI

struct ExerciseReportView: View {
    @State var viewModel: ExerciseReportViewModel
    @State private var pdfURL: URL?

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
            if let pb = viewModel.personalBest, let weight = pb.weight {
                Section {
                    LabeledContent("Personal best") {
                        Text(WeightFormatter.string(weight, unit: viewModel.unit)).fontWeight(.semibold)
                    }
                }
            }
            Section("Top-set weight") {
                ExerciseProgressChart(points: viewModel.points, personalBest: viewModel.personalBest,
                                      metric: \.topSetWeight, unitLabel: WeightFormatter.label(viewModel.unit))
            }
            Section("Estimated 1RM (Epley)") {
                ExerciseProgressChart(points: viewModel.points, personalBest: nil,
                                      metric: \.est1RM, unitLabel: WeightFormatter.label(viewModel.unit))
            }
            Section("Total reps") {
                ExerciseProgressChart(points: viewModel.points, personalBest: nil,
                                      metric: \.totalRepsMetric, unitLabel: "reps")
            }
            Section("History") {
                if viewModel.history.isEmpty {
                    Text("No sets recorded yet").foregroundStyle(.secondary)
                }
                ForEach(viewModel.history) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.sessionStart.formatted(date: .abbreviated, time: .omitted))
                        Text(viewModel.summary(of: entry.sets))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(viewModel.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let pdfURL {
                ShareLink(item: pdfURL) { Label("Share report", systemImage: "square.and.arrow.up") }
            }
        }
        .task { await viewModel.load(); renderPDF() }
        .onDisappear {
            // Rendered reports hold client PII: sweep them once the screen is gone.
            pdfURL = nil
            ReportExporter.removeReports()
        }
    }

    private func renderPDF() {
        guard viewModel.hasEnoughData else { pdfURL = nil; return }
        pdfURL = try? ReportExporter.renderPDF(
            clientName: viewModel.client.name, exerciseName: viewModel.exercise.name,
            points: viewModel.points, personalBest: viewModel.personalBest, unit: viewModel.unit
        )
    }
}
```

`ExerciseProgressChart` stays declared in `ClientReportView.swift` (same module).

#### 4. Overview view model, stripped
**File**: `Sources/Features/Reports/ClientReportViewModel.swift`
**Action**: modify. Remove `selectedExerciseId`, `points`, `personalBest`, `hasEnoughData`,
`loadChart()`. Add `errorMessage`. `load()` becomes:

```swift
var exercisesWithData: [ExerciseDTO] = []
var errorMessage: String?

func load() async {
    errorMessage = nil
    do {
        let ids = Set(try await reporting.exercisesWithData(clientId: client.id))
        let all = try await exerciseRepo.all()
        exercisesWithData = all.filter { ids.contains($0.id) }
    } catch {
        Log.ui.error("client report load failed: \(error.localizedDescription)")
        errorMessage = "Couldn't load progress."
    }
}
```

#### 5. Overview view, list of links
**File**: `Sources/Features/Reports/ClientReportView.swift`
**Action**: modify `ClientReportView` (keep `ExerciseProgressChart` below it). Remove
`selectedUnit`, `pdfURL`, `renderPDF()`, the toolbar, `.onChange`, `.onDisappear`.

```swift
struct ClientReportView: View {
    @State var viewModel: ClientReportViewModel

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
            if viewModel.exercisesWithData.isEmpty {
                ContentUnavailableView(/* unchanged */)
            } else {
                Section("Exercises") {
                    ForEach(viewModel.exercisesWithData) { exercise in
                        NavigationLink(exercise.name) {
                            ExerciseReportView(viewModel: ExerciseReportViewModel(
                                reporting: viewModel.reporting, client: viewModel.client, exercise: exercise
                            ))
                        }
                    }
                }
            }
        }
        .navigationTitle("\(viewModel.client.name) — Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
```

Make `reporting` on `ClientReportViewModel` `let` (not `private`) so the link can pass it.

#### 6. Link text
**File**: `Sources/Features/Clients/ClientDetailView.swift`
**Action**: modify line 44: `NavigationLink("View progress")`.

#### 7. Tests
**File**: `Tests/ReportingTests.swift`
**Action**: add

```swift
@Test func historyGroupsBySessionNewestFirst() async throws {
    let env = try makeEnv()
    try await addSession(env, start: daysAgo(10), sets: [(185, 5), (190, 3)], status: .completed)
    try await addSession(env, start: daysAgo(3), sets: [(200, 5)], status: .completed)
    try await addSession(env, start: daysAgo(1), sets: [(300, 1)], status: .cancelled)

    let history = try await env.reporting.historyBySession(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(history.count == 2)
    #expect(history[0].sets.map(\.weight) == [200])
    #expect(history[1].sets.map(\.weight) == [185, 190])
    #expect(history[1].sets.map(\.setIndex) == [0, 1])
}

@Test func historyKeepsTwoSessionsOnOneDayDistinct() async throws {
    let env = try makeEnv()
    let morning = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: daysAgo(2))!
    try await addSession(env, start: morning, sets: [(185, 5)], status: .completed)
    try await addSession(env, start: morning.addingTimeInterval(8 * 3600), sets: [(195, 5)], status: .completed)

    let history = try await env.reporting.historyBySession(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(history.count == 2)
    #expect(history.map { $0.sets.first?.weight } == [195, 185])

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.count == 1) // progression still merges by day
}
```

### Verification
#### Automated
- [x] `xcodegen generate` picks up the two new files; test command passes (9 reporting tests).
#### Manual
- [x] Device: Client → "View progress" lists exercises with data; tapping one shows PB, three charts, history rows like "Oct 20  185 lb × 5, 190 lb × 3", newest first.
- [x] Device: share button appears on the exercise screen when two or more days have data; the PDF opens in Files preview.
- [x] Device: navigating back and killing the app leaves nothing under `tmp/Reports` (check via Xcode → Devices → Download Container, or trust the unchanged sweep code).

---

## Phase 3: Consistency with window picker

### Changes

#### 1. Window and consistency query
**File**: `Sources/Persistence/ReportingQueries.swift`
**Action**: modify

Add after `SessionHistoryEntry`:

```swift
/// How far back the client overview looks. Top exercises ignore it.
enum ReportWindow: String, CaseIterable, Identifiable, Sendable {
    case fourWeeks, twelveWeeks, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fourWeeks: "4 weeks"
        case .twelveWeeks: "12 weeks"
        case .all: "All time"
        }
    }

    /// nil means unbounded.
    func start(from now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .fourWeeks: calendar.date(byAdding: .weekOfYear, value: -4, to: now)
        case .twelveWeeks: calendar.date(byAdding: .weekOfYear, value: -12, to: now)
        case .all: nil
        }
    }
}

/// Sessions in a window bucketed by status. `unresolved` are past sessions still
/// marked scheduled; they are reported but excluded from the rate.
struct ConsistencySummary: Sendable, Equatable {
    let completed: Int
    let cancelled: Int
    let noShow: Int
    let unresolved: Int

    var resolved: Int { completed + cancelled + noShow }
    /// 0...1, or nil when nothing has been resolved yet.
    var rate: Double? { resolved == 0 ? nil : Double(completed) / Double(resolved) }
}
```

Protocol:

```swift
/// Status counts for sessions with startAt in [from, to). Future sessions never count.
func consistency(clientId: UUID, from: Date?, to: Date) async throws -> ConsistencySummary
```

Actor:

```swift
func consistency(clientId: UUID, from: Date?, to: Date) async throws -> ConsistencySummary {
    let floor = from ?? .distantPast
    let sessions = try modelContext.fetch(
        FetchDescriptor<Session>(
            predicate: #Predicate { $0.clientId == clientId && $0.startAt >= floor && $0.startAt < to }
        )
    )
    var completed = 0, cancelled = 0, noShow = 0, unresolved = 0
    for session in sessions {
        switch session.status {
        case .completed: completed += 1
        case .cancelled: cancelled += 1
        case .noShow: noShow += 1
        case .scheduled: unresolved += 1
        }
    }
    return ConsistencySummary(completed: completed, cancelled: cancelled, noShow: noShow, unresolved: unresolved)
}
```

#### 2. View model
**File**: `Sources/Features/Reports/ClientReportViewModel.swift`
**Action**: modify

```swift
var window: ReportWindow = .twelveWeeks
var consistency: ConsistencySummary?

func load() async {
    errorMessage = nil
    do {
        let ids = Set(try await reporting.exercisesWithData(clientId: client.id))
        let all = try await exerciseRepo.all()
        exercisesWithData = all.filter { ids.contains($0.id) }
        try await loadWindowed()
    } catch { /* unchanged */ }
}

/// Everything the window picker affects.
func reloadWindow() async {
    do { try await loadWindowed() } catch {
        Log.ui.error("client report window load failed: \(error.localizedDescription)")
        errorMessage = "Couldn't load progress."
    }
}

private func loadWindowed() async throws {
    let now = Date.now
    consistency = try await reporting.consistency(clientId: client.id, from: window.start(from: now), to: now)
}
```

#### 3. View
**File**: `Sources/Features/Reports/ClientReportView.swift`
**Action**: modify. Inside the non-empty branch, before `Section("Exercises")`:

```swift
Section {
    Picker("Window", selection: $viewModel.window) {
        ForEach(ReportWindow.allCases) { Text($0.title).tag($0) }
    }
    .pickerStyle(.segmented)
}
if let c = viewModel.consistency {
    Section("Consistency") {
        if let rate = c.rate {
            LabeledContent("Completed") {
                Text(rate.formatted(.percent.precision(.fractionLength(0)))).fontWeight(.semibold)
            }
            Text("\(c.completed) completed · \(c.cancelled) cancelled · \(c.noShow) no-show")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Text("No resolved sessions in this window").foregroundStyle(.secondary)
        }
        if c.unresolved > 0 {
            Text("\(c.unresolved) past \(c.unresolved == 1 ? "session" : "sessions") still marked scheduled")
                .font(.caption).foregroundStyle(.orange)
        }
    }
}
```

Add `.onChange(of: viewModel.window) { Task { await viewModel.reloadWindow() } }` after `.task`.

#### 4. Tests
**File**: `Tests/ReportingTests.swift`
**Action**: add

```swift
@Test func consistencyRateCountsResolvedOnly() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 20, weight: 100, status: .completed)
    try await addSession(env, daysAgo: 15, weight: 100, status: .completed)
    try await addSession(env, daysAgo: 10, weight: 100, status: .completed)
    try await addSession(env, daysAgo: 8, weight: 100, status: .cancelled)
    try await addSession(env, daysAgo: 5, weight: 100, status: .scheduled) // forgotten

    let c = try await env.reporting.consistency(clientId: env.clientId, from: nil, to: .now)
    #expect(c == ConsistencySummary(completed: 3, cancelled: 1, noShow: 0, unresolved: 1))
    #expect(c.rate == 0.75)
}

@Test func consistencyIgnoresFutureScheduled() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 3, weight: 100, status: .noShow)
    try await addSession(env, daysAgo: -3, weight: 100, status: .scheduled) // upcoming

    let c = try await env.reporting.consistency(clientId: env.clientId, from: nil, to: .now)
    #expect(c.unresolved == 0)
    #expect(c.noShow == 1)
    #expect(c.rate == 0)
}

@Test func consistencyRespectsWindowStart() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 40, weight: 100, status: .cancelled)
    try await addSession(env, daysAgo: 10, weight: 100, status: .completed)

    let all = try await env.reporting.consistency(clientId: env.clientId, from: nil, to: .now)
    #expect(all.rate == 0.5)
    let fourWeeks = try await env.reporting.consistency(
        clientId: env.clientId, from: ReportWindow.fourWeeks.start(from: .now), to: .now)
    #expect(fourWeeks == ConsistencySummary(completed: 1, cancelled: 0, noShow: 0, unresolved: 0))
    #expect(ReportWindow.all.start(from: .now) == nil)
}
```

### Verification
#### Automated
- [x] Test command passes (12 reporting tests).
#### Manual
- [x] Device: a client with 3 completed, 1 cancelled and 1 forgotten past session shows "75 %", the counts line and "1 past session still marked scheduled".
- [x] Device: switching 12 weeks → 4 weeks changes the counts; "All time" restores them.

---

## Phase 4: Weekly volume chart and session volume list

### Changes

#### 1. Volume types and queries
**File**: `Sources/Persistence/ReportingQueries.swift`
**Action**: modify

Add after `ConsistencySummary`:

```swift
/// Weight moved, kept per unit because sets are never converted.
struct VolumeTotals: Sendable, Equatable {
    var byUnit: [Unit: Double] = [:]
    var isEmpty: Bool { byUnit.values.allSatisfy { $0 == 0 } }

    mutating func add(_ amount: Double, unit: Unit) {
        byUnit[unit, default: 0] += amount
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        var out = lhs
        for (unit, amount) in rhs.byUnit { out.add(amount, unit: unit) }
        return out
    }
}

struct SessionVolume: Sendable, Identifiable, Equatable {
    /// The session id.
    let id: UUID
    let start: Date
    let totals: VolumeTotals
}

struct WeeklyVolume: Sendable, Identifiable, Equatable {
    /// Start of the calendar week.
    let id: Date
    let totals: VolumeTotals
}
```

Protocol:

```swift
/// Σ(weight × reps) per completed session in [from, to), newest first. Sets missing
/// either value contribute nothing. Keyed by the exercise's current defaultUnit.
func sessionVolumes(clientId: UUID, from: Date?, to: Date) async throws -> [SessionVolume]
/// sessionVolumes summed per calendar week, oldest first.
func weeklyVolumes(clientId: UUID, from: Date?, to: Date) async throws -> [WeeklyVolume]
```

Actor:

```swift
func sessionVolumes(clientId: UUID, from: Date?, to: Date) async throws -> [SessionVolume] {
    let sessions = try completedSessions(clientId: clientId, from: from, to: to)
    let unitByExercise = try unitsByExerciseId()
    let records = try setRecords(forInstanceIds: sessions.flatMap { $0.instances.map(\.id) })
    let byInstance = Dictionary(grouping: records, by: \.workoutInstanceId)
    return sessions
        .map { session in
            var totals = VolumeTotals()
            for instance in session.instances {
                for set in byInstance[instance.id] ?? [] {
                    guard let weight = set.weight, let reps = set.reps else { continue }
                    totals.add(weight * Double(reps), unit: unitByExercise[set.exerciseId] ?? .lb)
                }
            }
            return SessionVolume(id: session.id, start: session.startAt, totals: totals)
        }
        .sorted { $0.start > $1.start }
}

func weeklyVolumes(clientId: UUID, from: Date?, to: Date) async throws -> [WeeklyVolume] {
    let calendar = Calendar.current
    let sessions = try await sessionVolumes(clientId: clientId, from: from, to: to)
    let byWeek = Dictionary(grouping: sessions) {
        calendar.dateInterval(of: .weekOfYear, for: $0.start)?.start ?? calendar.startOfDay(for: $0.start)
    }
    return byWeek
        .map { week, sessions in
            WeeklyVolume(id: week, totals: sessions.map(\.totals).reduce(VolumeTotals(), +))
        }
        .sorted { $0.id < $1.id }
}

// MARK: - Private (add)

private func unitsByExerciseId() throws -> [UUID: Unit] {
    let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
    return Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.defaultUnit) })
}
```

#### 2. Volume string
**File**: `Sources/Support/WeightFormatter.swift`
**Action**: add

```swift
/// "12,450 lb · 300 kg"; units with no volume are omitted; "—" when nothing.
static func volumeString(_ totals: VolumeTotals) -> String {
    let parts = [Unit.lb, .kg].compactMap { unit -> String? in
        guard let amount = totals.byUnit[unit], amount > 0 else { return nil }
        return string(amount, unit: unit)
    }
    return parts.isEmpty ? "—" : parts.joined(separator: " · ")
}
```

Any non-lb/kg unit on a weighted set is folded into lb by `label`; `volumeString` only
reads `.lb` and `.kg`, so the actor must map non-weight units to `.lb` when adding:
in `sessionVolumes` use `let unit = unitByExercise[set.exerciseId] ?? .lb;
totals.add(weight * Double(reps), unit: unit == .kg ? .kg : .lb)`.

#### 3. Chart view
**File**: `Sources/Features/Reports/ClientReportView.swift`
**Action**: add below `ExerciseProgressChart`

```swift
struct VolumeChart: View {
    let weeks: [WeeklyVolume]

    private struct Bar: Identifiable {
        let id: String
        let week: Date
        let unit: String
        let amount: Double
    }

    private var bars: [Bar] {
        weeks.flatMap { week in
            [Unit.lb, .kg].compactMap { unit in
                guard let amount = week.totals.byUnit[unit], amount > 0 else { return nil }
                return Bar(id: "\(week.id.timeIntervalSince1970)-\(unit.rawValue)", week: week.id,
                           unit: WeightFormatter.label(unit), amount: amount)
            }
        }
    }

    var body: some View {
        if weeks.count < ProgressPoint.minimumPoints {
            ContentUnavailableView("Not enough data yet", systemImage: "chart.bar",
                                   description: Text("Volume appears after two weeks of completed sessions."))
            .frame(height: 180)
        } else {
            Chart(bars) { bar in
                BarMark(x: .value("Week", bar.week, unit: .weekOfYear), y: .value("Volume", bar.amount))
                    .foregroundStyle(by: .value("Unit", bar.unit))
            }
            .chartYAxisLabel("weight × reps")
            .frame(height: 220)
            .padding(.vertical, 4)
        }
    }
}
```

#### 4. View model
**File**: `Sources/Features/Reports/ClientReportViewModel.swift`
**Action**: modify. Add `var weeklyVolumes: [WeeklyVolume] = []` and
`var sessionVolumes: [SessionVolume] = []`; extend `loadWindowed()`:

```swift
let from = window.start(from: now)
consistency = try await reporting.consistency(clientId: client.id, from: from, to: now)
sessionVolumes = try await reporting.sessionVolumes(clientId: client.id, from: from, to: now)
weeklyVolumes = try await reporting.weeklyVolumes(clientId: client.id, from: from, to: now)
```

#### 5. View sections
**File**: `Sources/Features/Reports/ClientReportView.swift`
**Action**: modify. After the Consistency section:

```swift
Section("Weekly volume") {
    VolumeChart(weeks: viewModel.weeklyVolumes)
}
Section("Sessions") {
    if viewModel.sessionVolumes.isEmpty {
        Text("No completed sessions in this window").foregroundStyle(.secondary)
    }
    ForEach(viewModel.sessionVolumes) { session in
        LabeledContent(session.start.formatted(date: .abbreviated, time: .omitted)) {
            Text(WeightFormatter.volumeString(session.totals))
        }
    }
}
```

#### 6. Tests
**File**: `Tests/ReportingTests.swift`
**Action**: modify `Env`/`makeEnv` to add `exercises: SwiftDataExerciseRepository`
(constructed from the same container) and a helper:

```swift
private func makeExercise(_ env: Env, name: String, unit: Unit) async throws -> UUID {
    try await env.exercises.create(ExerciseDTO(
        id: UUID(), name: name, category: .strength, metrics: [.weight, .reps, .sets],
        defaultUnit: unit, isCustom: true, createdAt: .now, updatedAt: .now
    )).id
}

/// A fixed Wednesday 07:00 `weeksAgo` weeks back, so week grouping never straddles a boundary.
private func midWeek(weeksAgo: Int) -> Date {
    let calendar = Calendar.current
    let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
    let week = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeek)!
    return calendar.date(byAdding: DateComponents(day: 3, hour: 7), to: week)!
}
```

Tests:

```swift
@Test func sessionVolumeSumsWeightTimesReps() async throws {
    let env = try makeEnv()
    let squat = try await makeExercise(env, name: "Squat", unit: .lb)
    let id = try await addSession(env, start: daysAgo(3), sets: [(185, 5), (185, 5), (nil, 10), (200, nil)],
                                  status: .completed, exerciseId: squat)

    let volumes = try await env.reporting.sessionVolumes(clientId: env.clientId, from: nil, to: .now)
    #expect(volumes.map(\.id) == [id])
    #expect(volumes[0].totals.byUnit == [.lb: 1850])
}

@Test func volumeKeepsUnitsSeparate() async throws {
    let env = try makeEnv()
    let squat = try await makeExercise(env, name: "Squat", unit: .lb)
    let press = try await makeExercise(env, name: "Press", unit: .kg)
    let start = daysAgo(2)
    let session = try await addSession(env, start: start, sets: [(100, 10)], status: .completed, exerciseId: squat)
    let instance = try await env.sessions.get(id: session)!.instances.first!.id
    try await env.sessions.recordSet(SetRecordDTO(
        id: UUID(), workoutInstanceId: instance, exerciseId: press, setIndex: 0, weight: 40, reps: 5,
        duration: nil, distance: nil, rpe: nil, performedAt: start, createdAt: .now, updatedAt: .now))

    let volumes = try await env.reporting.sessionVolumes(clientId: env.clientId, from: nil, to: .now)
    #expect(volumes[0].totals.byUnit == [.lb: 1000, .kg: 200])
    #expect(WeightFormatter.volumeString(volumes[0].totals) == "1,000 lb · 200 kg")
}

@Test func weeklyVolumeGroupsByCalendarWeek() async throws {
    let env = try makeEnv()
    let squat = try await makeExercise(env, name: "Squat", unit: .lb)
    try await addSession(env, start: midWeek(weeksAgo: 2), sets: [(100, 10)], status: .completed, exerciseId: squat)
    try await addSession(env, start: midWeek(weeksAgo: 1), sets: [(100, 10)], status: .completed, exerciseId: squat)
    try await addSession(env, start: midWeek(weeksAgo: 1).addingTimeInterval(86_400), sets: [(100, 5)],
                         status: .completed, exerciseId: squat)
    try await addSession(env, start: midWeek(weeksAgo: 1), sets: [(500, 5)], status: .cancelled, exerciseId: squat)

    let weeks = try await env.reporting.weeklyVolumes(clientId: env.clientId, from: nil, to: .now)
    #expect(weeks.map { $0.totals.byUnit[.lb] } == [1000, 1500])
    #expect(weeks[0].id < weeks[1].id)
}
```

**File**: `Tests/WeightFormatterTests.swift`
**Action**: add

```swift
@Test func volumeStringOmitsZeroUnits() {
    #expect(WeightFormatter.volumeString(VolumeTotals(byUnit: [.lb: 12450])) == "12,450 lb")
    #expect(WeightFormatter.volumeString(VolumeTotals(byUnit: [.lb: 0, .kg: 300])) == "300 kg")
    #expect(WeightFormatter.volumeString(VolumeTotals()) == "—")
}
```

### Verification
#### Automated
- [x] Test command passes (15 reporting tests, 4 formatter tests).
#### Manual
- [x] Device: a client with lb and kg exercises shows two bar series in "Weekly volume" and session rows like "Oct 20  1,000 lb · 200 kg".
- [x] Device: a window with fewer than two weeks of sessions shows "Not enough data yet" under the chart heading while the session rows still list.

---

## Phase 5: Top exercises ranking

### Changes

#### 1. Summary query
**File**: `Sources/Persistence/ReportingQueries.swift`
**Action**: modify

Add after `WeeklyVolume`:

```swift
/// All-time standing of one exercise for a client, from completed sessions.
struct ExerciseSummary: Sendable, Identifiable, Equatable {
    /// The exercise id.
    let id: UUID
    let sessionCount: Int
    let lastPerformed: Date
    let bestWeight: Double?
    /// Highest single-session rep total; nil when no set recorded reps.
    let bestTotalReps: Int?
}
```

Protocol:

```swift
/// Exercises with completed-session data, most-trained first (ties: most recent).
func topExercises(clientId: UUID) async throws -> [ExerciseSummary]
```

Actor:

```swift
func topExercises(clientId: UUID) async throws -> [ExerciseSummary] {
    let sessions = try completedSessions(clientId: clientId)
    var sessionByInstance: [UUID: UUID] = [:]
    for session in sessions {
        for instance in session.instances { sessionByInstance[instance.id] = session.id }
    }
    let records = try setRecords(forInstanceIds: Array(sessionByInstance.keys))
    return Dictionary(grouping: records, by: \.exerciseId)
        .map { exerciseId, sets in
            let bySession = Dictionary(grouping: sets) { sessionByInstance[$0.workoutInstanceId] ?? $0.workoutInstanceId }
            let repTotals = bySession.values.map { $0.compactMap(\.reps).reduce(0, +) }.filter { $0 > 0 }
            return ExerciseSummary(
                id: exerciseId,
                sessionCount: bySession.count,
                lastPerformed: sets.map(\.performedAt).max() ?? .distantPast,
                bestWeight: sets.compactMap(\.weight).max(),
                bestTotalReps: repTotals.max()
            )
        }
        .sorted {
            $0.sessionCount != $1.sessionCount ? $0.sessionCount > $1.sessionCount
                                                : $0.lastPerformed > $1.lastPerformed
        }
}
```

#### 2. View model
**File**: `Sources/Features/Reports/ClientReportViewModel.swift`
**Action**: modify. Replace `exercisesWithData` with:

```swift
struct TopExercise: Identifiable {
    let summary: ExerciseSummary
    let exercise: ExerciseDTO
    var id: UUID { exercise.id }
}

var topExercises: [TopExercise] = []

// in load(), replacing the exercisesWithData lines:
let summaries = try await reporting.topExercises(clientId: client.id)
let byId = Dictionary(uniqueKeysWithValues: try await exerciseRepo.all().map { ($0.id, $0) })
topExercises = summaries.compactMap { summary in
    byId[summary.id].map { TopExercise(summary: summary, exercise: $0) }
}

/// Second line of a top-exercise row and the overview page.
static func detail(for item: TopExercise) -> String {
    let sessions = "\(item.summary.sessionCount) \(item.summary.sessionCount == 1 ? "session" : "sessions")"
    if let weight = item.summary.bestWeight {
        return "\(sessions) · PB \(WeightFormatter.string(weight, unit: item.exercise.defaultUnit))"
    }
    if let reps = item.summary.bestTotalReps {
        return "\(sessions) · best \(reps) reps"
    }
    return "\(sessions) · no weight recorded"
}
```

The `exercisesWithData` query stays on the protocol (still used by tests) but the
overview no longer calls it.

#### 3. View rows
**File**: `Sources/Features/Reports/ClientReportView.swift`
**Action**: modify. Empty-state check becomes `viewModel.topExercises.isEmpty`.
Replace `Section("Exercises")` with:

```swift
Section("Top exercises") {
    ForEach(viewModel.topExercises) { item in
        NavigationLink {
            ExerciseReportView(viewModel: ExerciseReportViewModel(
                reporting: viewModel.reporting, client: viewModel.client, exercise: item.exercise))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exercise.name)
                Text(ClientReportViewModel.detail(for: item)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
```

#### 4. Tests
**File**: `Tests/ReportingTests.swift`
**Action**: add

```swift
@Test func topExercisesRankBySessionCountThenRecency() async throws {
    let env = try makeEnv()
    let squat = try await makeExercise(env, name: "Squat", unit: .lb)
    let bench = try await makeExercise(env, name: "Bench", unit: .lb)
    let row = try await makeExercise(env, name: "Row", unit: .lb)
    try await addSession(env, start: daysAgo(20), sets: [(100, 5)], status: .completed, exerciseId: squat)
    try await addSession(env, start: daysAgo(10), sets: [(120, 5)], status: .completed, exerciseId: squat)
    try await addSession(env, start: daysAgo(5), sets: [(80, 5)], status: .completed, exerciseId: bench)
    try await addSession(env, start: daysAgo(2), sets: [(60, 5)], status: .completed, exerciseId: row)
    try await addSession(env, start: daysAgo(1), sets: [(200, 5)], status: .cancelled, exerciseId: bench)

    let top = try await env.reporting.topExercises(clientId: env.clientId)
    #expect(top.map(\.id) == [squat, row, bench])
    #expect(top[0].sessionCount == 2)
    #expect(top[0].bestWeight == 120)
}

@Test func topExercisesReportBestRepsForUnweighted() async throws {
    let env = try makeEnv()
    let pushup = try await makeExercise(env, name: "Push-up", unit: .lb)
    try await addSession(env, start: daysAgo(5), sets: [(nil, 15), (nil, 12)], status: .completed, exerciseId: pushup)
    try await addSession(env, start: daysAgo(2), sets: [(nil, 20), (nil, 10)], status: .completed, exerciseId: pushup)

    let top = try await env.reporting.topExercises(clientId: env.clientId)
    #expect(top.count == 1)
    #expect(top[0].bestWeight == nil)
    #expect(top[0].bestTotalReps == 30)
}
```

### Verification
#### Automated
- [x] Test command passes (17 reporting tests).
#### Manual
- [x] Device: the most-trained exercise is first with "N sessions · PB 225 lb"; a push-up exercise shows "best 30 reps"; tapping any row opens its exercise screen.

---

## Phase 6: PNG export, overview page, surfaced render errors

### Changes

#### 1. Chart height parameter
**File**: `Sources/Features/Reports/ClientReportView.swift`
**Action**: modify `ExerciseProgressChart`: add `var height: CGFloat = 220` after
`unitLabel` and use it in both `.frame(height:)` calls (`height` for the chart,
`height - 40` for the placeholder). Same on `VolumeChart`.

#### 2. Exporter
**File**: `Sources/Services/ReportExporter.swift`
**Action**: rewrite the `ReportExporter` enum; rename `ReportPage` → `ExerciseReportPage`
and add `ClientOverviewPage`.

```swift
import SwiftUI
import UIKit

struct ReportFiles: Equatable {
    let pdf: URL
    let png: URL
}

/// Renders a report page to a shareable PDF and PNG.
enum ReportExporter {
    static let pageSize = CGSize(width: 612, height: 792) // US Letter @72dpi

    /// Sweeps earlier reports, renders `page` as `<baseName>.pdf` and `<baseName>.png`.
    @MainActor
    static func render(_ page: some View, baseName: String) throws -> ReportFiles {
        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = .init(pageSize)
        renderer.scale = 3

        // Reports hold client PII: keep them in their own tmp folder so the view
        // can sweep them on disappear, and protect the files like the data store.
        let fm = FileManager.default
        removeReports()
        try fm.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        let name = sanitized(baseName)
        let pdf = reportsDirectory.appending(path: "\(name).pdf")
        let png = reportsDirectory.appending(path: "\(name).png")

        var renderError: Error?
        renderer.render { size, renderIn in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let context = CGContext(pdf as CFURL, mediaBox: &mediaBox, nil) else {
                renderError = CocoaError(.fileWriteUnknown)
                return
            }
            context.beginPDFPage(nil)
            renderIn(context)
            context.endPDFPage()
            context.closePDF()
        }
        if let renderError { throw renderError }

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: png, options: .completeFileProtection)
        try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: pdf.path)
        return ReportFiles(pdf: pdf, png: png)
    }

    static let reportsDirectory = /* unchanged */
    static func removeReports() { /* unchanged */ }
    private static func sanitized(_ name: String) -> String { /* unchanged */ }
}
```

Remove `renderPDF(...)`.

```swift
/// The printable per-exercise page.
struct ExerciseReportPage: View {
    let clientName: String
    let exerciseName: String
    let points: [ProgressPoint]
    let personalBest: SetRecordDTO?
    let unit: Unit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TrainMe Progress Report").font(.title.bold())
            Text(clientName).font(.title2)
            Text(exerciseName).font(.headline).foregroundStyle(.secondary)
            if let pb = personalBest, let weight = pb.weight {
                Text("Personal best: \(WeightFormatter.string(weight, unit: unit)) on \(pb.performedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
            }
            Text("Top-set weight").font(.caption.bold())
            ExerciseProgressChart(points: points, personalBest: personalBest, metric: \.topSetWeight,
                                  unitLabel: WeightFormatter.label(unit), height: 150)
            Text("Estimated 1RM (Epley)").font(.caption.bold())
            ExerciseProgressChart(points: points, personalBest: nil, metric: \.est1RM,
                                  unitLabel: WeightFormatter.label(unit), height: 150)
            Text("Total reps").font(.caption.bold())
            ExerciseProgressChart(points: points, personalBest: nil, metric: \.totalRepsMetric,
                                  unitLabel: "reps", height: 150)
            Text("Generated \(Date.now.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(32)
        .frame(width: ReportExporter.pageSize.width, height: ReportExporter.pageSize.height, alignment: .topLeading)
        .background(.white)
    }
}

/// The printable client overview page.
struct ClientOverviewPage: View {
    let clientName: String
    let window: ReportWindow
    let consistency: ConsistencySummary?
    let weeks: [WeeklyVolume]
    /// (exercise name, detail line) already formatted by the view model.
    let topExercises: [(name: String, detail: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TrainMe Progress Report").font(.title.bold())
            Text(clientName).font(.title2)
            Text(window.title).font(.headline).foregroundStyle(.secondary)
            if let c = consistency, let rate = c.rate {
                Text("Consistency: \(rate.formatted(.percent.precision(.fractionLength(0)))) — \(c.completed) completed, \(c.cancelled) cancelled, \(c.noShow) no-show")
                    .font(.subheadline)
            }
            Text("Weekly volume").font(.caption.bold())
            VolumeChart(weeks: weeks, height: 180)
            Text("Top exercises").font(.caption.bold())
            ForEach(Array(topExercises.prefix(8).enumerated()), id: \.offset) { _, item in
                HStack { Text(item.name); Spacer(); Text(item.detail).foregroundStyle(.secondary) }
                    .font(.subheadline)
            }
            Text("Generated \(Date.now.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(32)
        .frame(width: ReportExporter.pageSize.width, height: ReportExporter.pageSize.height, alignment: .topLeading)
        .background(.white)
    }
}
```

#### 3. Share menu on both screens
**Files**: `Sources/Features/Reports/ExerciseReportView.swift`,
`Sources/Features/Reports/ClientReportView.swift`
**Action**: modify. In each view replace `@State private var pdfURL: URL?` with:

```swift
@State private var files: ReportFiles?
@State private var exportError: String?
```

Toolbar (both):

```swift
.toolbar {
    if let files {
        Menu {
            ShareLink("Share PDF", item: files.pdf)
            ShareLink("Share PNG", item: files.png)
        } label: {
            Label("Share report", systemImage: "square.and.arrow.up")
        }
    }
}
```

List: add after the `errorMessage` row in each view:

```swift
if let exportError {
    Section { Text(exportError).foregroundStyle(.red) }
}
```

`.onDisappear` (both): `files = nil; ReportExporter.removeReports()`.

`ExerciseReportView.renderReport()` (replaces `renderPDF`):

```swift
private func renderReport() {
    exportError = nil
    guard viewModel.hasEnoughData else { files = nil; return }
    do {
        files = try ReportExporter.render(
            ExerciseReportPage(clientName: viewModel.client.name, exerciseName: viewModel.exercise.name,
                               points: viewModel.points, personalBest: viewModel.personalBest, unit: viewModel.unit),
            baseName: "\(viewModel.client.name) — \(viewModel.exercise.name) Progress")
    } catch {
        Log.ui.error("report render failed: \(error.localizedDescription)")
        files = nil
        exportError = "Couldn't prepare the report for sharing."
    }
}
```

`ClientReportView.renderReport()` (new; called after `load()` in `.task` and after
`reloadWindow()` in `.onChange`):

```swift
private func renderReport() {
    exportError = nil
    guard !viewModel.topExercises.isEmpty else { files = nil; return }
    do {
        files = try ReportExporter.render(
            ClientOverviewPage(clientName: viewModel.client.name, window: viewModel.window,
                               consistency: viewModel.consistency, weeks: viewModel.weeklyVolumes,
                               topExercises: viewModel.topExercises.map { ($0.exercise.name, ClientReportViewModel.detail(for: $0)) }),
            baseName: "\(viewModel.client.name) — Overview")
    } catch { /* same as above */ }
}
```

Add `.onDisappear { files = nil; ReportExporter.removeReports() }` to `ClientReportView`.

#### 4. Tests
**File**: `Tests/ReportExporterTests.swift`
**Action**: create

```swift
import Foundation
import Testing
import UIKit
@testable import TrainMe

private func samplePoints() -> [ProgressPoint] {
    [ProgressPoint(date: .now.addingTimeInterval(-86_400 * 7), topSetWeight: 185, est1RM: 215, totalReps: 10),
     ProgressPoint(date: .now, topSetWeight: 195, est1RM: 227, totalReps: 10)]
}

@Test @MainActor func renderWritesPdfAndPng() throws {
    let page = ExerciseReportPage(clientName: "Sam", exerciseName: "Back Squat",
                                  points: samplePoints(), personalBest: nil, unit: .lb)
    let files = try ReportExporter.render(page, baseName: "Sam — Back Squat Progress")
    defer { ReportExporter.removeReports() }

    let fm = FileManager.default
    #expect(fm.fileExists(atPath: files.pdf.path))
    #expect(fm.fileExists(atPath: files.png.path))
    #expect(files.pdf.lastPathComponent == "Sam — Back Squat Progress.pdf")
    let data = try Data(contentsOf: files.png)
    #expect(!data.isEmpty)
    #expect(UIImage(data: data) != nil)
}

@Test @MainActor func renderSweepsPreviousReportsAndSanitizesNames() throws {
    let page = ClientOverviewPage(clientName: "A/B:C", window: .all, consistency: nil, weeks: [], topExercises: [])
    let first = try ReportExporter.render(page, baseName: "first")
    let second = try ReportExporter.render(page, baseName: "A/B:C — Overview")
    defer { ReportExporter.removeReports() }

    #expect(!FileManager.default.fileExists(atPath: first.pdf.path))
    #expect(second.pdf.lastPathComponent == "A-B-C — Overview.pdf")
    #expect(second.png.lastPathComponent == "A-B-C — Overview.png")
}
```

If `renderer.uiImage` returns nil on the simulator under test, change the PNG
assertions to `#expect(files.png.lastPathComponent.hasSuffix(".png"))`, note it in the
plan, and verify the PNG on device instead.

### Verification
#### Automated
- [x] `xcodegen generate`; test command passes including `ReportExporterTests`.
#### Manual
- [x] Device: overview Share menu offers PDF and PNG; the PNG matches the screen (consistency, bar chart, top exercises); the PDF is one Letter page.
- [x] Device: exercise Share menu offers PDF and PNG; the PDF shows all three charts.
- [x] Device: AirDrop the PNG to the Mac and open it; it is 1836×2376 and legible.
- [x] Simulated failure: temporarily make `reportsDirectory` point at `/` in a debug build; the red "Couldn't prepare the report for sharing." row appears and the Share menu is absent. Revert.

---

## Phase 7: Device verification and backlog close-out

### Changes

#### 1. Backlog
**File**: `BACKLOG.md`
**Action**: modify. Remove rows 1, 2, 3, 4, 9, 10 from "P1 — features" and append to
the "Done" table with a new preamble line "Addressed in PR #NN":

| # | Item | Resolution | Issue |
|---|------|------------|-------|
| 1 | Session volume per session / week | `sessionVolumes` / `weeklyVolumes` on `ReportingQueries`; per-unit totals, never converted; overview bar chart + session rows | #3 |
| 2 | Training consistency | `consistency(clientId:from:to:)`; completed ÷ resolved, unresolved past sessions reported separately; window picker 4w / 12w / all | #4 |
| 3 | Client-level summary of top exercises | `topExercises` ranked by session count then recency; overview rows link to the exercise screen | #5 |
| 4 | Per-exercise history list | `historyBySession`; `ExerciseReportView` "History" section | #6 |
| 9 | Report as PNG image | `ReportExporter.render` writes PDF and PNG at 3×; Share menu on both screens | #11 |
| 10 | Total-reps progression chart | `ProgressPoint.totalReps`; third chart on the exercise screen and page | #12 |

Also delete the trailing "Still worth a look" sentence about `ClientReportView`
swallowing a failed PDF render (fixed in Phase 6); keep the `ReminderCoordinator` note.

#### 2. Plan record
**File**: `thoughts/qrspi/2026-10-26-p1-reporting/plan.md`
**Action**: tick every checkbox that passed; add a dated line under this phase listing
device, build and the outcome, matching the tech-debt plan's convention.

#### 3. Pull request
Body lists the six issues as `Closes #3, #4, #5, #6, #11, #12` and links
`thoughts/qrspi/2026-10-26-p1-reporting/design.md`.

### Verification
#### Automated
- [x] CI green on the PR.
#### Manual
- [x] Full device pass on madphone with the final branch build: every manual checkbox in Phases 1–6 re-run once against that build.
- [x] Record: `- 2026-MM-DD: Phases 1–6 manual checks performed on madphone (iPhone 16 Pro Max) against the full branch build; all passed.`

- 2026-10-26: Phases 1–6 manual checks performed on madphone (iPhone 16 Pro Max) against the full branch build (2efbd7a, Debug); all passed.
- 2026-10-26: PR opened as [#34](https://github.com/madacgrav/trainme/pull/34).
- 2026-10-26: CI green on #34 (`test` check); merged into main as 1d51824. Issues #3, #4, #5, #6, #11, #12 closed.
