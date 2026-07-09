import Foundation
import SwiftData

@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.workout)
    var entries: [WorkoutEntry] = []
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class WorkoutEntry {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var order: Int
    var targetSets: Int?
    var targetReps: Int?
    var targetWeight: Double?
    var targetDuration: Int?
    var workout: Workout?

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
