import Foundation
import Testing
@testable import TrainMe

private func makeRepo() throws -> SwiftDataClientRepository {
    let container = try PersistenceController.makeContainer(inMemory: true)
    return SwiftDataClientRepository(modelContainer: container)
}

private func dto(id: UUID = UUID(), name: String, phone: String = "+15551234567") -> ClientDTO {
    ClientDTO(
        id: id, name: name, phoneE164: phone,
        goal: nil, injuries: nil, notes: nil,
        isArchived: false, createdAt: .now, updatedAt: .now
    )
}

@Test func upsertAndFetchRoundTrip() async throws {
    let repo = try makeRepo()
    try await repo.upsert(dto(name: "Sam"))

    let all = try await repo.all()
    #expect(all.count == 1)
    #expect(all.first?.name == "Sam")
    #expect(all.first?.phoneE164 == "+15551234567")
}

@Test func upsertUpdatesExistingById() async throws {
    let repo = try makeRepo()
    let id = UUID()

    try await repo.upsert(dto(id: id, name: "Sam"))
    var updated = dto(id: id, name: "Samantha")
    updated.goal = "Strength"
    updated.injuries = "Left knee"
    updated.notes = "Prefers mornings"
    try await repo.upsert(updated)

    let all = try await repo.all()
    #expect(all.count == 1)
    #expect(all.first?.name == "Samantha")
    #expect(all.first?.goal == "Strength")
    #expect(all.first?.injuries == "Left knee")
    #expect(all.first?.notes == "Prefers mornings")
}

@Test func deleteRemovesClient() async throws {
    let repo = try makeRepo()
    let id = UUID()

    try await repo.upsert(dto(id: id, name: "Sam"))
    try await repo.delete(id: id)

    #expect(try await repo.all().isEmpty)
}

@Test func searchMatchesSubstringCaseInsensitive() async throws {
    let repo = try makeRepo()
    try await repo.upsert(dto(name: "Samantha Jones"))
    try await repo.upsert(dto(name: "Alex Smith"))

    let results = try await repo.search("sam")
    #expect(results.count == 1)
    #expect(results.first?.name == "Samantha Jones")

    let empty = try await repo.search("")
    #expect(empty.count == 2)
}

@Test func archivedClientsLeaveActiveListAndSearch() async throws {
    let repo = try makeRepo()
    let id = UUID()
    try await repo.upsert(dto(id: id, name: "Sam"))
    try await repo.upsert(dto(name: "Alex"))

    try await repo.setArchived(id: id, true)

    let active = try await repo.all()
    #expect(active.count == 1)
    #expect(active.first?.name == "Alex")
    #expect(try await repo.search("Sam").isEmpty)
    #expect(try await repo.allIncludingArchived().count == 2)

    try await repo.setArchived(id: id, false)
    #expect(try await repo.all().count == 2)
}
