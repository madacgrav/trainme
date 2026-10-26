import Foundation
import Testing
@testable import TrainMe

actor FakeCalendar: CalendarSyncing {
    private(set) var removed: [String] = []
    private(set) var updated: [String] = []

    func requestAccess() async -> Bool { true }

    func push(_ session: SessionDTO, clientName: String, recurrence: AppRecurrence?) async throws -> String? {
        "evt-new"
    }

    func update(eventIdentifier: String, _ session: SessionDTO, clientName: String) async throws -> String? {
        updated.append(eventIdentifier)
        return eventIdentifier
    }

    func remove(eventIdentifier: String) async throws {
        removed.append(eventIdentifier)
    }
}

@MainActor
private final class Flag {
    var raised = false
}

@MainActor
@Test func deleteRemovesCalendarEventAndSession() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let sessions = SwiftDataSessionRepository(modelContainer: container)
    let dto = SessionDTO(
        id: UUID(), clientId: UUID(), startAt: .now, endAt: .now.addingTimeInterval(3600),
        status: .scheduled, notes: nil, instances: [], seriesId: nil, recurrence: nil,
        eventIdentifier: nil, createdAt: .now, updatedAt: .now
    )
    try await sessions.schedule(dto, attaching: [])
    try await sessions.setEventIdentifier(id: dto.id, "evt-1")
    let stored = try #require(try await sessions.get(id: dto.id))
    let calendar = FakeCalendar()
    let reloaded = Flag()

    let vm = SessionRunViewModel(
        sessionRepo: sessions,
        exerciseRepo: SwiftDataExerciseRepository(modelContainer: container),
        clientRepo: SwiftDataClientRepository(modelContainer: container),
        calendar: calendar,
        session: stored,
        clientName: "Sam",
        onStatusChanged: { reloaded.raised = true }
    )
    #expect(vm.canEdit)

    await vm.delete()

    #expect(await calendar.removed == ["evt-1"])
    let after = try await sessions.get(id: dto.id)
    #expect(after == nil)
    #expect(reloaded.raised)
}
