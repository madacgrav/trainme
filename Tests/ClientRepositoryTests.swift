import Foundation
import Testing
@testable import TrainMe

@Test func upsertAndFetchRoundTrip() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let repo = SwiftDataClientRepository(modelContainer: container)

    try await repo.upsert(ClientDTO(id: UUID(), name: "Sam", createdAt: .now, updatedAt: .now))

    let all = try await repo.all()
    #expect(all.count == 1)
    #expect(all.first?.name == "Sam")
}

@Test func upsertUpdatesExistingById() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let repo = SwiftDataClientRepository(modelContainer: container)
    let id = UUID()

    try await repo.upsert(ClientDTO(id: id, name: "Sam", createdAt: .now, updatedAt: .now))
    try await repo.upsert(ClientDTO(id: id, name: "Samantha", createdAt: .now, updatedAt: .now))

    let all = try await repo.all()
    #expect(all.count == 1)
    #expect(all.first?.name == "Samantha")
}

@Test func deleteRemovesClient() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let repo = SwiftDataClientRepository(modelContainer: container)
    let id = UUID()

    try await repo.upsert(ClientDTO(id: id, name: "Sam", createdAt: .now, updatedAt: .now))
    try await repo.delete(id: id)

    let all = try await repo.all()
    #expect(all.isEmpty)
}
