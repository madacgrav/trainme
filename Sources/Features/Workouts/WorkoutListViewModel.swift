import Foundation
import Observation

@MainActor
@Observable
final class WorkoutListViewModel {
    let workoutRepo: any WorkoutRepository
    let exerciseRepo: any ExerciseRepository
    var workouts: [WorkoutDTO] = []

    init(workoutRepo: any WorkoutRepository, exerciseRepo: any ExerciseRepository) {
        self.workoutRepo = workoutRepo
        self.exerciseRepo = exerciseRepo
    }

    func load() async {
        workouts = (try? await workoutRepo.all()) ?? []
    }

    func duplicate(id: UUID) async {
        _ = try? await workoutRepo.duplicate(id: id)
        await load()
    }

    func delete(id: UUID) async {
        try? await workoutRepo.delete(id: id)
        await load()
    }
}
