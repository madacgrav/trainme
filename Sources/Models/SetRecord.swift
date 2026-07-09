import Foundation
import SwiftData

@Model
final class SetRecord {
    @Attribute(.unique) var id: UUID
    var workoutInstanceId: UUID
    var exerciseId: UUID
    var setIndex: Int
    var weight: Double?
    var reps: Int?
    var duration: Int?
    var distance: Double?
    var rpe: Double?
    var performedAt: Date
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        workoutInstanceId: UUID,
        exerciseId: UUID,
        setIndex: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        duration: Int? = nil,
        distance: Double? = nil,
        rpe: Double? = nil,
        performedAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workoutInstanceId = workoutInstanceId
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.distance = distance
        self.rpe = rpe
        self.performedAt = performedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
