import Foundation
import Observation

@MainActor
@Observable
final class ClientListViewModel {
    let repository: any ClientRepository
    let exerciseRepo: any ExerciseRepository
    let sessionRepo: any SessionRepository
    let reporting: any ReportingQueries
    var clients: [ClientDTO] = []
    var query: String = ""

    init(
        repo: any ClientRepository,
        exerciseRepo: any ExerciseRepository,
        sessionRepo: any SessionRepository,
        reporting: any ReportingQueries
    ) {
        self.repository = repo
        self.exerciseRepo = exerciseRepo
        self.sessionRepo = sessionRepo
        self.reporting = reporting
    }

    func load() async {
        clients = (try? await repository.search(query)) ?? []
    }
}
