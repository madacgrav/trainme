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

/// Schedules a session with one instance, records one set, applies the status.
private func addSession(
    _ env: Env,
    daysAgo: Int,
    weight: Double,
    reps: Int = 5,
    status: SessionStatus
) async throws {
    let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
    let template = WorkoutDTO(
        id: UUID(), name: "W",
        entries: [WorkoutEntryDTO(id: UUID(), exerciseId: env.exerciseId, order: 0, targetSets: nil, targetReps: nil, targetWeight: nil, targetDuration: nil)],
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
    try await env.sessions.recordSet(SetRecordDTO(
        id: UUID(), workoutInstanceId: instanceId, exerciseId: env.exerciseId,
        setIndex: 0, weight: weight, reps: reps, duration: nil, distance: nil,
        rpe: nil, performedAt: start, createdAt: .now, updatedAt: .now
    ))
    try await env.sessions.setStatus(id: dto.id, status)
}

@Test func progressionExcludesCancelledAndNoShow() async throws {
    let env = try makeEnv()
    try await addSession(env, daysAgo: 21, weight: 185, status: .completed)
    try await addSession(env, daysAgo: 14, weight: 500, status: .cancelled)
    try await addSession(env, daysAgo: 10, weight: 400, status: .noShow)
    try await addSession(env, daysAgo: 7, weight: 195, status: .completed)

    let points = try await env.reporting.progression(clientId: env.clientId, exerciseId: env.exerciseId)
    #expect(points.count == 2)
    #expect(points.map(\.topSetWeight) == [185, 195])
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
