import Foundation
import Observation

@MainActor
@Observable
final class ExerciseListViewModel {
    let repository: any ExerciseRepository
    var exercises: [ExerciseDTO] = []
    var query: String = ""
    var categoryFilter: ExerciseCategory?

    init(repo: any ExerciseRepository) {
        self.repository = repo
    }

    var filtered: [ExerciseDTO] {
        guard let categoryFilter else { return exercises }
        return exercises.filter { $0.category == categoryFilter }
    }

    func load() async {
        exercises = (try? await repository.search(prefix: query)) ?? []
    }
}
