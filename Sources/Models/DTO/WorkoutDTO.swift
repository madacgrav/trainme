import Foundation

struct WorkoutEntryDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var exerciseId: UUID
    var order: Int
    var targetSets: Int?
    var targetReps: Int?
    var targetWeight: Double?
    var targetDuration: Int?
}

struct WorkoutDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var entries: [WorkoutEntryDTO]
    var createdAt: Date
    var updatedAt: Date
}

extension WorkoutEntryDTO {
    init(_ model: WorkoutEntry) {
        self.init(
            id: model.id,
            exerciseId: model.exerciseId,
            order: model.order,
            targetSets: model.targetSets,
            targetReps: model.targetReps,
            targetWeight: model.targetWeight,
            targetDuration: model.targetDuration
        )
    }

    func toModel() -> WorkoutEntry {
        WorkoutEntry(
            id: id,
            exerciseId: exerciseId,
            order: order,
            targetSets: targetSets,
            targetReps: targetReps,
            targetWeight: targetWeight,
            targetDuration: targetDuration
        )
    }
}

extension WorkoutDTO {
    init(_ model: Workout) {
        self.init(
            id: model.id,
            name: model.name,
            entries: model.entries.sorted { $0.order < $1.order }.map(WorkoutEntryDTO.init),
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
}
