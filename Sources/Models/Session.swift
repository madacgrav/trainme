import Foundation
import SwiftData

enum SessionStatus: String, Codable, Sendable, CaseIterable {
    case scheduled, completed, cancelled, noShow
}

/// App-side recurrence model, mirrored into EKRecurrenceRule when pushing to the
/// system calendar (Phase 7b). Weekday numbering follows EKWeekday: 1=Sun … 7=Sat.
struct AppRecurrence: Codable, Sendable, Equatable {
    enum Frequency: String, Codable, Sendable {
        case daily, weekly
    }

    var frequency: Frequency
    var interval: Int
    var weekdays: [Int]
    var endDate: Date?
    var occurrenceCount: Int?
}

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var clientId: UUID
    var startAt: Date
    var endAt: Date
    var statusRaw: String = SessionStatus.scheduled.rawValue
    var notes: String?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutInstance.session)
    var instances: [WorkoutInstance] = []
    var seriesId: UUID?
    var recurrenceData: Data?
    var eventIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        clientId: UUID,
        startAt: Date,
        endAt: Date,
        status: SessionStatus = .scheduled,
        notes: String? = nil,
        seriesId: UUID? = nil,
        recurrenceData: Data? = nil,
        eventIdentifier: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.clientId = clientId
        self.startAt = startAt
        self.endAt = endAt
        self.statusRaw = status.rawValue
        self.notes = notes
        self.seriesId = seriesId
        self.recurrenceData = recurrenceData
        self.eventIdentifier = eventIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: SessionStatus { SessionStatus(rawValue: statusRaw) ?? .scheduled }
}

@Model
final class WorkoutInstance {
    @Attribute(.unique) var id: UUID
    var sourceWorkoutId: UUID
    var name: String = ""
    @Relationship(deleteRule: .cascade, inverse: \PlannedEntry.instance)
    var plannedEntries: [PlannedEntry] = []
    var session: Session?

    init(id: UUID = UUID(), sourceWorkoutId: UUID, name: String) {
        self.id = id
        self.sourceWorkoutId = sourceWorkoutId
        self.name = name
    }
}

@Model
final class PlannedEntry {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var order: Int
    var targetSets: Int?
    var targetReps: Int?
    var targetWeight: Double?
    var targetDuration: Int?
    var instance: WorkoutInstance?

    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        order: Int,
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetDuration: Int? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetDuration = targetDuration
    }
}
