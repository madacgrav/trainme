import EventKit
import Foundation
import SwiftData
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

/// Wraps a real repository and fails selected calls.
actor FailingSessionRepo: SessionRepository {
    struct Boom: Error {}
    let inner: SwiftDataSessionRepository
    private var failDelete = false
    private var failSetStatus = false
    private var failRecordSet = false

    init(inner: SwiftDataSessionRepository) { self.inner = inner }

    func fail(delete: Bool = false, setStatus: Bool = false, recordSet: Bool = false) {
        failDelete = delete
        failSetStatus = setStatus
        failRecordSet = recordSet
    }

    func delete(id: UUID) async throws {
        if failDelete { throw Boom() }
        try await inner.delete(id: id)
    }
    func setStatus(id: UUID, _ status: SessionStatus) async throws {
        if failSetStatus { throw Boom() }
        try await inner.setStatus(id: id, status)
    }
    func recordSet(_ dto: SetRecordDTO) async throws {
        if failRecordSet { throw Boom() }
        try await inner.recordSet(dto)
    }

    // Everything else forwards verbatim.
    func schedule(_ dto: SessionDTO, attaching workoutIds: [UUID]) async throws {
        try await inner.schedule(dto, attaching: workoutIds)
    }
    func scheduleSeries(_ dto: SessionDTO, recurrence: AppRecurrence, attaching workoutIds: [UUID], horizonWeeks: Int) async throws -> ScheduledSeries {
        try await inner.scheduleSeries(dto, recurrence: recurrence, attaching: workoutIds, horizonWeeks: horizonWeeks)
    }
    func get(id: UUID) async throws -> SessionDTO? { try await inner.get(id: id) }
    func sessions(from: Date, to: Date) async throws -> [SessionDTO] { try await inner.sessions(from: from, to: to) }
    func upcoming(after: Date, limit: Int) async throws -> [SessionDTO] { try await inner.upcoming(after: after, limit: limit) }
    func forClient(_ clientId: UUID) async throws -> [SessionDTO] { try await inner.forClient(clientId) }
    func update(_ dto: SessionDTO) async throws { try await inner.update(dto) }
    func setEventIdentifier(id: UUID, _ eventIdentifier: String?) async throws {
        try await inner.setEventIdentifier(id: id, eventIdentifier)
    }
    func setEventIdentifierForSeries(_ seriesId: UUID, _ eventIdentifier: String?) async throws {
        try await inner.setEventIdentifierForSeries(seriesId, eventIdentifier)
    }
    func updateNotes(id: UUID, _ notes: String?) async throws { try await inner.updateNotes(id: id, notes) }
    func completedCount(since: Date?) async throws -> Int { try await inner.completedCount(since: since) }
    func deleteSet(id: UUID) async throws { try await inner.deleteSet(id: id) }
    func setsFor(instanceId: UUID) async throws -> [SetRecordDTO] { try await inner.setsFor(instanceId: instanceId) }
    func lastSet(clientId: UUID, exerciseId: UUID) async throws -> SetRecordDTO? {
        try await inner.lastSet(clientId: clientId, exerciseId: exerciseId)
    }
}

private struct FailingEnv {
    let container: ModelContainer
    let real: SwiftDataSessionRepository
    let repo: FailingSessionRepo
    let calendar: FakeCalendar
    let dto: SessionDTO
    let instanceId: UUID
    let exerciseId: UUID
    let vm: SessionRunViewModel
}

/// A stored session with one workout instance, an event identifier, and a
/// view model wired to a failing repository wrapper.
@MainActor
private func makeFailingEnv() async throws -> FailingEnv {
    let container = try PersistenceController.makeContainer(inMemory: true)
    let real = SwiftDataSessionRepository(modelContainer: container)
    let workouts = SwiftDataWorkoutRepository(modelContainer: container)
    let exerciseId = UUID()
    let template = WorkoutDTO(
        id: UUID(), name: "Legs",
        entries: [WorkoutEntryDTO(id: UUID(), exerciseId: exerciseId, order: 0, targetSets: 3, targetReps: 5, targetWeight: 185, targetDuration: nil)],
        createdAt: .now, updatedAt: .now
    )
    try await workouts.upsert(template)
    let dto = SessionDTO(
        id: UUID(), clientId: UUID(), startAt: .now, endAt: .now.addingTimeInterval(3600),
        status: .scheduled, notes: nil, instances: [], seriesId: nil, recurrence: nil,
        eventIdentifier: nil, createdAt: .now, updatedAt: .now
    )
    try await real.schedule(dto, attaching: [template.id])
    try await real.setEventIdentifier(id: dto.id, "evt-1")
    let stored = try #require(try await real.get(id: dto.id))
    let repo = FailingSessionRepo(inner: real)
    let calendar = FakeCalendar()
    let vm = SessionRunViewModel(
        sessionRepo: repo,
        exerciseRepo: SwiftDataExerciseRepository(modelContainer: container),
        clientRepo: SwiftDataClientRepository(modelContainer: container),
        calendar: calendar,
        session: stored,
        clientName: "Sam"
    )
    return FailingEnv(
        container: container, real: real, repo: repo, calendar: calendar, dto: stored,
        instanceId: stored.instances.first!.id, exerciseId: exerciseId, vm: vm
    )
}

@MainActor
@Test func failedDeleteReturnsFalseAndSetsError() async throws {
    let env = try await makeFailingEnv()
    await env.repo.fail(delete: true)

    let ok = await env.vm.delete()

    #expect(!ok)
    #expect(env.vm.errorMessage != nil)
    #expect(try await env.real.get(id: env.dto.id) != nil)
}

@MainActor
@Test func failedSetStatusKeepsEventIdentifier() async throws {
    let env = try await makeFailingEnv()
    await env.repo.fail(setStatus: true)

    await env.vm.setStatus(.cancelled)

    #expect(env.vm.errorMessage != nil)
    #expect(try await env.real.get(id: env.dto.id)?.eventIdentifier == "evt-1")
    #expect(await env.calendar.removed.isEmpty)
    #expect(try await env.real.get(id: env.dto.id)?.status == .scheduled)
}

@MainActor
@Test func failedRecordLeavesSetsUnchanged() async throws {
    let env = try await makeFailingEnv()
    await env.vm.load()
    let before = env.vm.recordedSets
    await env.repo.fail(recordSet: true)

    await env.vm.record(instanceId: env.instanceId, exerciseId: env.exerciseId, weight: 100, reps: 5, duration: nil, distance: nil)

    #expect(env.vm.errorMessage != nil)
    #expect(env.vm.recordedSets == before)
    #expect(try await env.real.setsFor(instanceId: env.instanceId).isEmpty)
}
