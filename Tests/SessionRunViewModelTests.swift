import EventKit
import Foundation
import Testing
@testable import TrainMe

actor FakeCalendar: CalendarSyncing {
    private(set) var removed: [String] = []
    private(set) var updated: [String] = []
    private var pushResult: Result<String?, any Error> = .success("evt-new")
    /// nil → echo the identifier back, like a successful in-place update.
    private var updateResult: Result<String?, any Error>?
    private var removeError: (any Error)?
    private var status: EKAuthorizationStatus = .fullAccess

    func configure(
        push: Result<String?, any Error>? = nil,
        update: Result<String?, any Error>? = nil,
        removeError: (any Error)? = nil,
        status: EKAuthorizationStatus? = nil
    ) {
        if let push { pushResult = push }
        if let update { updateResult = update }
        self.removeError = removeError
        if let status { self.status = status }
    }

    func requestAccess() async -> Bool { status == .fullAccess }

    func authorizationStatus() async -> EKAuthorizationStatus { status }

    func push(_ session: SessionDTO, clientName: String, recurrence: AppRecurrence?) async throws -> String? {
        try pushResult.get()
    }

    func update(eventIdentifier: String, _ session: SessionDTO, clientName: String) async throws -> String? {
        updated.append(eventIdentifier)
        if let updateResult { return try updateResult.get() }
        return eventIdentifier
    }

    func remove(eventIdentifier: String) async throws {
        if let removeError { throw removeError }
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
