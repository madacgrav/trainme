import Foundation

struct SetRecordDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
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
}

extension SetRecordDTO {
    init(_ model: SetRecord) {
        self.init(
            id: model.id,
            workoutInstanceId: model.workoutInstanceId,
            exerciseId: model.exerciseId,
            setIndex: model.setIndex,
            weight: model.weight,
            reps: model.reps,
            duration: model.duration,
            distance: model.distance,
            rpe: model.rpe,
            performedAt: model.performedAt,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    func toModel() -> SetRecord {
        SetRecord(
            id: id,
            workoutInstanceId: workoutInstanceId,
            exerciseId: exerciseId,
            setIndex: setIndex,
            weight: weight,
            reps: reps,
            duration: duration,
            distance: distance,
            rpe: rpe,
            performedAt: performedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
