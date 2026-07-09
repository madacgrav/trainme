import Foundation
import Observation

@MainActor
@Observable
final class ClientListViewModel {
    let repository: any ClientRepository
    var clients: [ClientDTO] = []
    var query: String = ""

    init(repo: any ClientRepository) {
        self.repository = repo
    }

    func load() async {
        clients = (try? await repository.search(query)) ?? []
    }
}
