import Foundation
import Testing
@testable import TrainMe

private struct Env {
    let sessions: SwiftDataSessionRepository
    let workouts: SwiftDataWorkoutRepository
    let reporting: SwiftDataReportingQueries
    let clientId = UUID()
    let exerciseId = UUID()
}

private func makeEnv() throws -> Env {
    let container = try PersistenceController.makeContainer(inMemory: true)
    return Env(
        sessions: SwiftDataSessionRepository(modelContainer: container),
        workouts: SwiftDataWorkoutRepository(modelContainer: container),
        reporting: SwiftDataReportingQueries(modelContainer: container)
    )
}

/// Schedules a session with one instance, records the given sets, applies the status.
/// Returns the session id.
@discardableResult
private func addSession(
    _ env: Env,
    start: Date,
    sets: [(weight: Double?, reps: Int?)],
    status: SessionStatus,
    exerciseId: UUID? = nil
) async throws -> UUID {
    let exerciseId = exerciseId ?? env.exerciseId
    let template = WorkoutDTO(
        id: UUID(), name: "W",
        entries: [WorkoutEntryDTO(id: UUID(), exerciseId: exerciseId, order: 0, targetSets: nil, targetReps: nil, targetWeight: nil, targetDuration: nil)],
        createdAt: .now, updatedAt: .now
    )
    try await env.workouts.upsert(template)
    let dto = SessionDTO(
        id: UUID(), clientId: env.clientId, startAt: start,
        endAt: start.addingTimeInterval(3600), status: .scheduled,
        notes: nil, instances: [], seriesId: nil, recurrence: nil,
        eventIdentifier: nil, createdAt: .now, updatedAt: .now
    )
    try await env.sessions.schedule(dto, attaching: [template.id])
    let instanceId = try await env.sessions.get(id: dto.id)!.instances.first!.id
    for (index, set) in sets.enumerated() {
        try await env.sessions.recordSet(SetRecordDTO(
            id: UUID(), workoutInstanceId: instanceId, exerciseId: exerciseId,
            setIndex: index, weight: set.weight, reps: set.reps, duration: nil, distance: nil,
            rpe: nil, performedAt: start.addingTimeInterval(Double(index) * 60),
            createdAt: .now, updatedAt: .now
        ))
    }
    try await env.sessions.setStatus(id: dto.id, status)
    return dto.id
}

private func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -days, to: .now)!
}

/// One-set convenience used by the original tests.
@discardableResult
private func addSession(
    _ env: Env, daysAgo days: Int, weight: Double?, reps: Int? = 5, status: SessionStatus
) async throws -> UUID {
    try await addSession(env, start: daysAgo(days), sets: [(weight, reps)], status: status)
}

@Test func progressionExcludesCancelledAndNoShow() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 21, weight: 185, status: .completed)
    try await addSession(env, daysAgo: 14, weight: 500, status: .cancelled)
    try await addSession(env, daysAgo: 10, weight: 400, status: .noShow)
    try await addSession(env, daysAgo: 7, weight: 195, status: .completed)

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.count == 2)
    #expect(points.compactMap(\.topSetWeight) == [185, 195])
}

@Test func personalBestIsHeaviestCompletedSet() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 21, weight: 185, status: .completed)
    try await addSession(env, daysAgo: 14, weight: 225, status: .completed)
    try await addSession(env, daysAgo: 7, weight: 205, status: .completed)
    try await addSession(env, daysAgo: 3, weight: 315, status: .cancelled) // must not count

    let pb = try await env.reporting.personalBest(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(pb?.weight == 225)
}

@Test func epleyFormula() {
    #expect(epley1RM(weight: 300, reps: 0) == 300)
    #expect(epley1RM(weight: 300, reps: nil) == 300)
    #expect(abs(epley1RM(weight: 200, reps: 5) - 233.333) < 0.01)
    #expect(abs(epley1RM(weight: 100, reps: 10) - 133.333) < 0.01)
}

@Test func sparseDataDetectable() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 7, weight: 185, status: .completed)

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.count == 1)
    #expect(points.count < 2) // the UI's "not enough data yet" threshold
}

@Test func exercisesWithDataOnlyListsCompleted() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 7, weight: 185, status: .cancelled)
    #expect(try await env.reporting.exercisesWithData(clientId: env.clientId).isEmpty)

    try await addSession(env, daysAgo: 3, weight: 185, status: .completed)
    #expect(try await env.reporting.exercisesWithData(clientId: env.clientId) == [env.exerciseId])
}

@Test func totalRepsSumsAcrossSets() async throws {
    let env = try makeEnv()
    try await addSession(env, start: daysAgo(7), sets: [(185, 5), (185, 5), (190, 3)], status: .completed)

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.count == 1)
    #expect(points.first?.totalReps == 13)
    #expect(points.first?.topSetWeight == 190)
}

@Test func repsOnlySetsProduceRepsPointWithoutWeight() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 7, weight: nil, reps: 20, status: .completed)
    try await addSession(env, daysAgo: 3, weight: nil, reps: 25, status: .completed)

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.map(\.totalReps) == [20, 25])
    #expect(points.allSatisfy { $0.topSetWeight == nil && $0.est1RM == nil })
    #expect(points.compactMap(\.totalRepsMetric).count == 2)

    let pb = try await env.reporting.personalBest(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(pb == nil)
}

@Test func historyGroupsBySessionNewestFirst() async throws {
    let env = try makeEnv()
    try await addSession(env, start: daysAgo(10), sets: [(185, 5), (190, 3)], status: .completed)
    try await addSession(env, start: daysAgo(3), sets: [(200, 5)], status: .completed)
    try await addSession(env, start: daysAgo(1), sets: [(300, 1)], status: .cancelled)

    let history = try await env.reporting.historyBySession(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(history.count == 2)
    #expect(history[0].sets.map(\.weight) == [200])
    #expect(history[1].sets.map(\.weight) == [185, 190])
    #expect(history[1].sets.map(\.setIndex) == [0, 1])
}

@Test func historyKeepsTwoSessionsOnOneDayDistinct() async throws {
    let env = try makeEnv()
    let morning = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: daysAgo(2))!
    try await addSession(env, start: morning, sets: [(185, 5)], status: .completed)
    try await addSession(env, start: morning.addingTimeInterval(8 * 3600), sets: [(195, 5)], status: .completed)

    let history = try await env.reporting.historyBySession(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(history.count == 2)
    #expect(history.map { $0.sets.first?.weight } == [195, 185])

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.count == 1) // progression still merges by day
}
