import Foundation
import SwiftData

enum ExerciseCategory: String, Codable, Sendable, CaseIterable {
    case strength, cardio, bodyweight, mobility
}

enum Unit: String, Codable, Sendable, CaseIterable {
    case lb, kg, mi, km, min, sec
}

/// Which inputs the recording UI shows for an exercise (PRD §4.5).
struct MetricSet: OptionSet, Sendable, Hashable {
    let rawValue: Int

    static let weight = MetricSet(rawValue: 1 << 0)
    static let reps = MetricSet(rawValue: 1 << 1)
    static let sets = MetricSet(rawValue: 1 << 2)
    static let duration = MetricSet(rawValue: 1 << 3)
    static let distance = MetricSet(rawValue: 1 << 4)
}

extension MetricSet: Codable {
    init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(Int.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String = ExerciseCategory.strength.rawValue
    var metricsRaw: Int = 0
    var defaultUnitRaw: String = Unit.lb.rawValue
    var isCustom: Bool = false
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        metrics: MetricSet,
        defaultUnit: Unit,
        isCustom: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.metricsRaw = metrics.rawValue
        self.defaultUnitRaw = defaultUnit.rawValue
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: ExerciseCategory { ExerciseCategory(rawValue: categoryRaw) ?? .strength }
    var metrics: MetricSet { MetricSet(rawValue: metricsRaw) }
    var defaultUnit: Unit { Unit(rawValue: defaultUnitRaw) ?? .lb }
}
