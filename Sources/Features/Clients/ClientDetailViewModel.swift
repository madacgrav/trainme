import Foundation
import Observation

@MainActor
@Observable
final class ClientDetailViewModel {
    let repository: any ClientRepository
    let exerciseRepo: any ExerciseRepository
    let reporting: any ReportingQueries
    var client: ClientDTO

    init(
        repo: any ClientRepository,
        exerciseRepo: any ExerciseRepository,
        reporting: any ReportingQueries,
        client: ClientDTO
    ) {
        self.repository = repo
        self.exerciseRepo = exerciseRepo
        self.reporting = reporting
        self.client = client
    }

    func reload() async {
        if let refreshed = try? await repository.allIncludingArchived().first(where: { $0.id == client.id }) {
            client = refreshed
        }
    }

    func toggleArchived() async {
        try? await repository.setArchived(id: client.id, !client.isArchived)
        await reload()
    }
}
