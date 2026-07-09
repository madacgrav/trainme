import Foundation
import SwiftData

protocol WorkoutRepository: Sendable {
    func all() async throws -> [WorkoutDTO]
    func get(id: UUID) async throws -> WorkoutDTO?
    func upsert(_ dto: WorkoutDTO) async throws
    func duplicate(id: UUID) async throws -> WorkoutDTO?
    func reorder(workoutId: UUID, entryIds: [UUID]) async throws
    func delete(id: UUID) async throws
}

@ModelActor
actor SwiftDataWorkoutRepository: WorkoutRepository {
    func all() async throws -> [WorkoutDTO] {
        try modelContext
            .fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.name)]))
            .map(WorkoutDTO.init)
    }

    func get(id: UUID) async throws -> WorkoutDTO? {
        try fetch(id: id).map(WorkoutDTO.init)
    }

    func upsert(_ dto: WorkoutDTO) async throws {
        if let existing = try fetch(id: dto.id) {
            existing.name = dto.name
            existing.updatedAt = .now
            // Replace entries wholesale: templates are small ordered lists.
            for entry in existing.entries {
                modelContext.delete(entry)
            }
            existing.entries.removeAll()
            existing.entries.append(contentsOf: dto.entries.map { $0.toModel() })
        } else {
            let workout = Workout(id: dto.id, name: dto.name, createdAt: dto.createdAt, updatedAt: dto.updatedAt)
            modelContext.insert(workout)
            workout.entries.append(contentsOf: dto.entries.map { $0.toModel() })
        }
        try modelContext.save()
    }

    /// Deep copy with fresh UUIDs for the workout and every entry.
    func duplicate(id: UUID) async throws -> WorkoutDTO? {
        guard let source = try fetch(id: id) else { return nil }
        let copy = Workout(id: UUID(), name: source.name + " Copy")
        modelContext.insert(copy)
        let copiedEntries = source.entries
            .sorted { $0.order < $1.order }
            .map { entry in
                WorkoutEntry(
                    id: UUID(),
                    exerciseId: entry.exerciseId,
                    order: entry.order,
                    targetSets: entry.targetSets,
                    targetReps: entry.targetReps,
                    targetWeight: entry.targetWeight,
                    targetDuration: entry.targetDuration
                )
            }
        copy.entries.append(contentsOf: copiedEntries)
        try modelContext.save()
        return WorkoutDTO(copy)
    }

    func reorder(workoutId: UUID, entryIds: [UUID]) async throws {
        guard let workout = try fetch(id: workoutId) else { return }
        for (index, entryId) in entryIds.enumerated() {
            workout.entries.first { $0.id == entryId }?.order = index
        }
        workout.updatedAt = .now
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        guard let existing = try fetch(id: id) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    private func fetch(id: UUID) throws -> Workout? {
        try modelContext.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })).first
    }
}
