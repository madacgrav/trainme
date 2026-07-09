import Foundation
import Observation

@MainActor
@Observable
final class WorkoutBuilderViewModel {
    private let workoutRepo: any WorkoutRepository
    let exerciseRepo: any ExerciseRepository
    private let existing: WorkoutDTO?

    var name: String
    var entries: [WorkoutEntryDTO]
    var exerciseNames: [UUID: String] = [:]

    init(workoutRepo: any WorkoutRepository, exerciseRepo: any ExerciseRepository, existing: WorkoutDTO?) {
        self.workoutRepo = workoutRepo
        self.exerciseRepo = exerciseRepo
        self.existing = existing
        self.name = existing?.name ?? ""
        self.entries = existing?.entries ?? []
    }

    var isEditing: Bool { existing != nil }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !entries.isEmpty
    }

    func loadExerciseNames() async {
        let all = (try? await exerciseRepo.all()) ?? []
        exerciseNames = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.name) })
    }

    func addExercise(_ exercise: ExerciseDTO) {
        let entry = WorkoutEntryDTO(
            id: UUID(),
            exerciseId: exercise.id,
            order: entries.count,
            targetSets: exercise.metrics.contains(.sets) ? 3 : nil,
            targetReps: exercise.metrics.contains(.reps) ? 10 : nil,
            targetWeight: nil,
            targetDuration: nil
        )
        entries.append(entry)
        exerciseNames[exercise.id] = exercise.name
    }

    func move(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        renumber()
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        renumber()
    }

    private func renumber() {
        for index in entries.indices {
            entries[index].order = index
        }
    }

    func save() async -> Bool {
        renumber()
        let dto = WorkoutDTO(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            entries: entries,
            createdAt: existing?.createdAt ?? .now,
            updatedAt: .now
        )
        do {
            try await workoutRepo.upsert(dto)
            return true
        } catch {
            return false
        }
    }
}
