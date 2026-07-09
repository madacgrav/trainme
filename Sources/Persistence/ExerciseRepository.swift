import Foundation
import SwiftData

protocol ExerciseRepository: Sendable {
    func all() async throws -> [ExerciseDTO]
    func search(prefix: String) async throws -> [ExerciseDTO]
    func create(_ dto: ExerciseDTO) async throws -> ExerciseDTO
    func createAll(_ dtos: [ExerciseDTO]) async throws
    func update(_ dto: ExerciseDTO) async throws
    func count() async throws -> Int
}

@ModelActor
actor SwiftDataExerciseRepository: ExerciseRepository {
    func all() async throws -> [ExerciseDTO] {
        try modelContext
            .fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
            .map(ExerciseDTO.init)
    }

    /// Autocomplete search: case-insensitive substring match so "bench" finds
    /// "Barbell Bench Press" (prefix matches trivially included).
    func search(prefix: String) async throws -> [ExerciseDTO] {
        guard !prefix.isEmpty else { return try await all() }
        return try modelContext
            .fetch(FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.name.localizedStandardContains(prefix) },
                sortBy: [SortDescriptor(\.name)]
            ))
            .map(ExerciseDTO.init)
    }

    func create(_ dto: ExerciseDTO) async throws -> ExerciseDTO {
        let model = dto.toModel()
        modelContext.insert(model)
        try modelContext.save()
        return ExerciseDTO(model)
    }

    func createAll(_ dtos: [ExerciseDTO]) async throws {
        for dto in dtos {
            modelContext.insert(dto.toModel())
        }
        try modelContext.save()
    }

    func update(_ dto: ExerciseDTO) async throws {
        let id = dto.id
        guard let existing = try modelContext
            .fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id }))
            .first
        else { return }
        existing.name = dto.name
        existing.categoryRaw = dto.category.rawValue
        existing.metricsRaw = dto.metrics.rawValue
        existing.defaultUnitRaw = dto.defaultUnit.rawValue
        existing.updatedAt = .now
        try modelContext.save()
    }

    func count() async throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Exercise>())
    }
}
