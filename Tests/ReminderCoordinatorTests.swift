import Foundation
import Testing
@testable import TrainMe

actor FakeNotifications: NotificationScheduling {
    private(set) var rescheduleCalls: [[UUID]] = []

    func requestAuthorization() async -> Bool { true }

    func reschedule(upcoming: [(id: UUID, startAt: Date, clientName: String)]) async {
        rescheduleCalls.append(upcoming.map(\.id))
    }
}

private func futureSession(clientId: UUID) -> SessionDTO {
    let start = Date.now.addingTimeInterval(86_400)
    return SessionDTO(
        id: UUID(), clientId: clientId, startAt: start,
        endAt: start.addingTimeInterval(3600), status: .scheduled,
        notes: nil, instances: [], seriesId: nil, recurrence: nil,
        eventIdentifier: nil, createdAt: .now, updatedAt: .now
    )
}

@MainActor
@Test func refreshReschedulesOnlyScheduledFutureSessions() async throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let sessions = SwiftDataSessionRepository(modelContainer: container)
    let clients = SwiftDataClientRepository(modelContainer: container)
    let fake = FakeNotifications()
    let sut = ReminderCoordinator(sessionRepo: sessions, clientRepo: clients, notifications: fake)

    let clientId = UUID()
    try await clients.upsert(ClientDTO(
        id: clientId, name: "Sam", phoneE164: "+15555550100", goal: nil, injuries: nil,
        notes: nil, isArchived: false, createdAt: .now, updatedAt: .now
    ))
    let kept = futureSession(clientId: clientId)
    let cancelled = futureSession(clientId: clientId)
    try await sessions.schedule(kept, attaching: [])
    try await sessions.schedule(cancelled, attaching: [])
    try await sessions.setStatus(id: cancelled.id, .cancelled)

    await sut.refresh()

    let calls = await fake.rescheduleCalls
    #expect(calls.count == 1)
    #expect(calls.first == [kept.id])
}
