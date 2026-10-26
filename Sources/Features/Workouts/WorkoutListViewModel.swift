import Foundation
import Observation

@MainActor
@Observable
final class WorkoutListViewModel {
    let workoutRepo: any WorkoutRepository
    let exerciseRepo: any ExerciseRepository
    var workouts: [WorkoutDTO] = []
    var errorMessage: String?

    init(workoutRepo: any WorkoutRepository, exerciseRepo: any ExerciseRepository) {
        self.workoutRepo = workoutRepo
        self.exerciseRepo = exerciseRepo
    }

    func load() async {
        do {
            workouts = try await workoutRepo.all()
        } catch {
            Log.ui.debug("workout list load failed: \(error.localizedDescription)")
        }
    }

    func duplicate(id: UUID) async {
        errorMessage = nil
        do {
            _ = try await workoutRepo.duplicate(id: id)
        } catch {
            Log.ui.error("duplicate workout failed: \(error.localizedDescription)")
            errorMessage = "Couldn't duplicate the workout."
        }
        await load()
    }

    func delete(id: UUID) async {
        errorMessage = nil
        do {
            try await workoutRepo.delete(id: id)
        } catch {
            Log.ui.error("delete workout failed: \(error.localizedDescription)")
            errorMessage = "Couldn't delete the workout."
        }
        await load()
    }
}
