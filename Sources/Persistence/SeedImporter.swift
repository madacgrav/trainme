import Foundation

/// One entry in the bundled seed library JSON.
private struct SeedExercise: Decodable {
    let name: String
    let category: ExerciseCategory
    let metrics: [String]
    let defaultUnit: Unit
}

enum SeedImporter {
    /// Imports the bundled seed library on first launch only. Idempotent:
    /// a non-empty exercise store is left untouched.
    static func seedIfEmpty(repo: any ExerciseRepository, bundle: Bundle = .main) async throws {
        guard try await repo.count() == 0 else { return }
        guard let url = bundle.url(forResource: "seed_exercises", withExtension: "json") else { return }

        let seeds = try JSONDecoder().decode([SeedExercise].self, from: Data(contentsOf: url))
        let dtos = seeds.map { seed in
            ExerciseDTO(
                id: UUID(),
                name: seed.name,
                category: seed.category,
                metrics: seed.metrics.reduce(into: MetricSet()) { set, name in
                    switch name {
                    case "weight": set.insert(.weight)
                    case "reps": set.insert(.reps)
                    case "sets": set.insert(.sets)
                    case "duration": set.insert(.duration)
                    case "distance": set.insert(.distance)
                    default: break
                    }
                },
                defaultUnit: seed.defaultUnit,
                isCustom: false,
                createdAt: .now,
                updatedAt: .now
            )
        }
        try await repo.createAll(dtos)
    }
}
