import Foundation
import SwiftData

protocol ClientRepository: Sendable {
    func all() async throws -> [ClientDTO]
    func upsert(_ dto: ClientDTO) async throws
    func delete(id: UUID) async throws
}

@ModelActor
actor SwiftDataClientRepository: ClientRepository {
    func all() async throws -> [ClientDTO] {
        try modelContext
            .fetch(FetchDescriptor<Client>(sortBy: [SortDescriptor(\.name)]))
            .map(ClientDTO.init)
    }

    func upsert(_ dto: ClientDTO) async throws {
        if let existing = try fetch(id: dto.id) {
            dto.apply(to: existing)
        } else {
            modelContext.insert(Client(id: dto.id, name: dto.name, createdAt: dto.createdAt, updatedAt: dto.updatedAt))
        }
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        guard let existing = try fetch(id: id) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    private func fetch(id: UUID) throws -> Client? {
        try modelContext.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.id == id })).first
    }
}
