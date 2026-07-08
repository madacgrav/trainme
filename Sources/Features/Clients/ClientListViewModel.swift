import Foundation
import Observation

@MainActor
@Observable
final class ClientListViewModel {
    private let repo: any ClientRepository
    var clients: [ClientDTO] = []

    init(repo: any ClientRepository) {
        self.repo = repo
    }

    func load() async {
        clients = (try? await repo.all()) ?? []
    }

    func add(name: String) async {
        try? await repo.upsert(ClientDTO(id: UUID(), name: name, createdAt: .now, updatedAt: .now))
        await load()
    }
}
