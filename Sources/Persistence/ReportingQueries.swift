import Foundation
import SwiftData

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

/// Every set of one exercise in one completed session, in set order.
struct SessionHistoryEntry: Sendable, Identifiable, Equatable {
    /// The workout instance id.
    let id: UUID
    let sessionStart: Date
    let sets: [SetRecordDTO]
}

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

/// Epley estimated one-rep max. Reps of 0/nil contribute the bare weight.
func epley1RM(weight: Double, reps: Int?) -> Double {
    weight * (1 + Double(reps ?? 0) / 30)
}

protocol ReportingQueries: Sendable {
    /// All set records for a client+exercise from COMPLETED sessions only.
    func history(clientId: UUID, exerciseId: UUID) async throws -> [SetRecordDTO]
    /// One point per day: max top-set weight, best Epley est. 1RM (nil without weighted sets) and total reps.
    func progression(clientId: UUID, exerciseId: UUID) async throws -> [ProgressPoint]
    /// The heaviest completed set for this client+exercise.
    func personalBest(clientId: UUID, exerciseId: UUID) async throws -> SetRecordDTO?
    /// Completed-session sets for this exercise grouped by session, newest first.
    func historyBySession(clientId: UUID, exerciseId: UUID) async throws -> [SessionHistoryEntry]
    /// Status counts for sessions with startAt in [from, to). Future sessions never count.
    func consistency(clientId: UUID, from: Date?, to: Date) async throws -> ConsistencySummary
    /// Σ(weight × reps) per completed session in [from, to), newest first. Sets missing
    /// either value contribute nothing. Keyed by the exercise's current defaultUnit.
    func sessionVolumes(clientId: UUID, from: Date?, to: Date) async throws -> [SessionVolume]
    /// sessionVolumes summed per calendar week, oldest first.
    func weeklyVolumes(clientId: UUID, from: Date?, to: Date) async throws -> [WeeklyVolume]
    /// Exercises with completed-session data, most-trained first (ties: most recent).
    func topExercises(clientId: UUID) async throws -> [ExerciseSummary]
    /// Exercises that have at least one completed-session set for this client.
    func exercisesWithData(clientId: UUID) async throws -> [UUID]
}

@ModelActor
actor SwiftDataReportingQueries: ReportingQueries {
    func history(clientId: UUID, exerciseId: UUID) async throws -> [SetRecordDTO] {
        try completedSetRecords(clientId: clientId)
            .filter { $0.exerciseId == exerciseId }
            .sorted { $0.performedAt < $1.performedAt }
            .map(SetRecordDTO.init)
    }

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

    func personalBest(clientId: UUID, exerciseId: UUID) async throws -> SetRecordDTO? {
        try await history(clientId: clientId, exerciseId: exerciseId)
            .filter { $0.weight != nil }
            .max { ($0.weight ?? 0) < ($1.weight ?? 0) }
    }

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
                        // Non-weight units fold into lb, matching WeightFormatter.label.
                        let unit = unitByExercise[set.exerciseId] ?? .lb
                        totals.add(weight * Double(reps), unit: unit == .kg ? .kg : .lb)
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

    func exercisesWithData(clientId: UUID) async throws -> [UUID] {
        Array(Set(try completedSetRecords(clientId: clientId).map(\.exerciseId)))
    }

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

    private func unitsByExerciseId() throws -> [UUID: Unit] {
        let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        return Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.defaultUnit) })
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
}
