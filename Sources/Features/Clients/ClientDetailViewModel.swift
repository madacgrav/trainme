import Foundation
import Observation

@MainActor
@Observable
final class ClientDetailViewModel {
    let repository: any ClientRepository
    var client: ClientDTO

    init(repo: any ClientRepository, client: ClientDTO) {
        self.repository = repo
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
