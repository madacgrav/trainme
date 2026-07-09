import Foundation
import SwiftData

struct ProgressPoint: Sendable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let topSetWeight: Double
    let est1RM: Double

    init(date: Date, topSetWeight: Double, est1RM: Double) {
        self.id = UUID()
        self.date = date
        self.topSetWeight = topSetWeight
        self.est1RM = est1RM
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date && lhs.topSetWeight == rhs.topSetWeight && lhs.est1RM == rhs.est1RM
    }
}

/// Epley estimated one-rep max. Reps of 0/nil contribute the bare weight.
func epley1RM(weight: Double, reps: Int?) -> Double {
    weight * (1 + Double(reps ?? 0) / 30)
}

protocol ReportingQueries: Sendable {
    /// All set records for a client+exercise from COMPLETED sessions only.
    func history(clientId: UUID, exerciseId: UUID) async throws -> [SetRecordDTO]
    /// One point per day: max top-set weight and best Epley est. 1RM.
    func progression(clientId: UUID, exerciseId: UUID) async throws -> [ProgressPoint]
    /// The heaviest completed set for this client+exercise.
    func personalBest(clientId: UUID, exerciseId: UUID) async throws -> SetRecordDTO?
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
            .filter { $0.weight != nil }
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.performedAt) }
        return byDay
            .map { day, sets in
                ProgressPoint(
                    date: day,
                    topSetWeight: sets.compactMap(\.weight).max() ?? 0,
                    est1RM: sets.map { epley1RM(weight: $0.weight ?? 0, reps: $0.reps) }.max() ?? 0
                )
            }
            .sorted { $0.date < $1.date }
    }

    func personalBest(clientId: UUID, exerciseId: UUID) async throws -> SetRecordDTO? {
        try await history(clientId: clientId, exerciseId: exerciseId)
            .filter { $0.weight != nil }
            .max { ($0.weight ?? 0) < ($1.weight ?? 0) }
    }

    func exercisesWithData(clientId: UUID) async throws -> [UUID] {
        Array(Set(try completedSetRecords(clientId: clientId).map(\.exerciseId)))
    }

    // MARK: - Private

    /// Set records joined to COMPLETED sessions for the client. Cancelled and
    /// no-show sessions are excluded from all reporting (PRD §8 data honesty).
    private func completedSetRecords(clientId: UUID) throws -> [SetRecord] {
        let completedRaw = SessionStatus.completed.rawValue
        let sessions = try modelContext.fetch(
            FetchDescriptor<Session>(
                predicate: #Predicate { $0.clientId == clientId && $0.statusRaw == completedRaw }
            )
        )
        let instanceIds = sessions.flatMap { $0.instances.map(\.id) }
        guard !instanceIds.isEmpty else { return [] }
        return try modelContext.fetch(
            FetchDescriptor<SetRecord>(
                predicate: #Predicate { instanceIds.contains($0.workoutInstanceId) }
            )
        )
    }
}
