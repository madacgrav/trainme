import Foundation
import SwiftData

protocol ClientRepository: Sendable {
    func all() async throws -> [ClientDTO]
    func allIncludingArchived() async throws -> [ClientDTO]
    func search(_ query: String) async throws -> [ClientDTO]
    func upsert(_ dto: ClientDTO) async throws
    func setArchived(id: UUID, _ archived: Bool) async throws
    func delete(id: UUID) async throws
}

@ModelActor
actor SwiftDataClientRepository: ClientRepository {
    func all() async throws -> [ClientDTO] {
        try modelContext
            .fetch(FetchDescriptor<Client>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.name)]
            ))
            .map(ClientDTO.init)
    }

    func allIncludingArchived() async throws -> [ClientDTO] {
        try modelContext
            .fetch(FetchDescriptor<Client>(sortBy: [SortDescriptor(\.name)]))
            .map(ClientDTO.init)
    }

    func search(_ query: String) async throws -> [ClientDTO] {
        guard !query.isEmpty else { return try await all() }
        return try modelContext
            .fetch(FetchDescriptor<Client>(
                predicate: #Predicate { !$0.isArchived && $0.name.localizedStandardContains(query) },
                sortBy: [SortDescriptor(\.name)]
            ))
            .map(ClientDTO.init)
    }

    func upsert(_ dto: ClientDTO) async throws {
        if let existing = try fetch(id: dto.id) {
            dto.apply(to: existing)
        } else {
            modelContext.insert(dto.toModel())
        }
        try modelContext.save()
    }

    func setArchived(id: UUID, _ archived: Bool) async throws {
        guard let existing = try fetch(id: id) else { return }
        existing.isArchived = archived
        existing.updatedAt = .now
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
