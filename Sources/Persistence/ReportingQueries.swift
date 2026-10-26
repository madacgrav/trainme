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
