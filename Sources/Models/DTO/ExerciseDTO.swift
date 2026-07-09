import Foundation

struct ExerciseDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var metrics: MetricSet
    var defaultUnit: Unit
    var isCustom: Bool
    var createdAt: Date
    var updatedAt: Date
}

extension ExerciseDTO {
    init(_ model: Exercise) {
        self.init(
            id: model.id,
            name: model.name,
            category: model.category,
            metrics: model.metrics,
            defaultUnit: model.defaultUnit,
            isCustom: model.isCustom,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    func toModel() -> Exercise {
        Exercise(
            id: id,
            name: name,
            category: category,
            metrics: metrics,
            defaultUnit: defaultUnit,
            isCustom: isCustom,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
