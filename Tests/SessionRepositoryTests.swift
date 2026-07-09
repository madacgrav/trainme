import Foundation
import Testing
@testable import TrainMe

private struct Repos {
    let sessions: SwiftDataSessionRepository
    let workouts: SwiftDataWorkoutRepository
}

private func makeRepos() throws -> Repos {
    let container = try PersistenceController.makeContainer(inMemory: true)
    return Repos(
        sessions: SwiftDataSessionRepository(modelContainer: container),
        workouts: SwiftDataWorkoutRepository(modelContainer: container)
    )
}

private func sessionDTO(clientId: UUID = UUID(), startAt: Date = .now) -> SessionDTO {
    SessionDTO(
        id: UUID(), clientId: clientId, startAt: startAt,
        endAt: startAt.addingTimeInterval(3600), status: .scheduled,
        notes: nil, instances: [], seriesId: nil, recurrence: nil,
        eventIdentifier: nil, createdAt: .now, updatedAt: .now
    )
}

@Test func schedulingCopiesTemplateIntoInstance() async throws {
    let repos = try makeRepos()
    let exerciseId = UUID()
    let template = WorkoutDTO(
        id: UUID(), name: "Leg Day A",
        entries: [WorkoutEntryDTO(id: UUID(), exerciseId: exerciseId, order: 0, targetSets: 3, targetReps: 5, targetWeight: 185, targetDuration: nil)],
        createdAt: .now, updatedAt: .now
    )
    try await repos.workouts.upsert(template)

    let dto = sessionDTO()
    try await repos.sessions.schedule(dto, attaching: [template.id])

    let fetched = try await repos.sessions.get(id: dto.id)
    #expect(fetched?.instances.count == 1)
    #expect(fetched?.instances.first?.name == "Leg Day A")
    #expect(fetched?.instances.first?.sourceWorkoutId == template.id)
    #expect(fetched?.instances.first?.plannedEntries.first?.targetWeight == 185)

    // Edit the template afterward — the scheduled instance must be untouched.
    var edited = template
    edited.name = "Leg Day A v2"
    edited.entries[0].targetWeight = 225
    try await repos.workouts.upsert(edited)

    let after = try await repos.sessions.get(id: dto.id)
    #expect(after?.instances.first?.name == "Leg Day A")
    #expect(after?.instances.first?.plannedEntries.first?.targetWeight == 185)
}

@Test func statusTransitionPersists() async throws {
    let repos = try makeRepos()
    let dto = sessionDTO()
    try await repos.sessions.schedule(dto, attaching: [])

    try await repos.sessions.setStatus(id: dto.id, .completed)
    #expect(try await repos.sessions.get(id: dto.id)?.status == .completed)

    try await repos.sessions.setStatus(id: dto.id, .noShow)
    #expect(try await repos.sessions.get(id: dto.id)?.status == .noShow)
}

@Test func seriesSchedulingSharesSeriesIdAndCopiesPerSession() async throws {
    let repos = try makeRepos()
    let template = WorkoutDTO(
        id: UUID(), name: "Push",
        entries: [WorkoutEntryDTO(id: UUID(), exerciseId: UUID(), order: 0, targetSets: 3, targetReps: 10, targetWeight: nil, targetDuration: nil)],
        createdAt: .now, updatedAt: .now
    )
    try await repos.workouts.upsert(template)

    // Tuesday 7am anchor
    var components = DateComponents(year: 2026, month: 7, day: 14, hour: 7) // a Tuesday
    let start = Calendar.current.date(from: components)!
    let dto = sessionDTO(startAt: start)
    let rule = AppRecurrence(frequency: .weekly, interval: 1, weekdays: [3, 5], endDate: nil, occurrenceCount: nil)
    try await repos.sessions.scheduleSeries(dto, recurrence: rule, attaching: [template.id], horizonWeeks: 2)

    components.day = 1
    let monthStart = Calendar.current.date(from: components)!
    let all = try await repos.sessions.sessions(from: monthStart, to: start.addingTimeInterval(60 * 60 * 24 * 30))
    #expect(all.count >= 4) // Tue/Thu over ~2 weeks
    let seriesIds = Set(all.map(\.seriesId))
    #expect(seriesIds.count == 1)
    #expect(seriesIds.first != nil)
    #expect(all.allSatisfy { $0.instances.count == 1 })
    // Every occurrence has its own instance copy (distinct instance ids)
    #expect(Set(all.compactMap { $0.instances.first?.id }).count == all.count)
}

@Test func upcomingReturnsOnlyScheduledSorted() async throws {
    let repos = try makeRepos()
    let now = Date.now
    let s1 = sessionDTO(startAt: now.addingTimeInterval(3600))
    let s2 = sessionDTO(startAt: now.addingTimeInterval(7200))
    let s3 = sessionDTO(startAt: now.addingTimeInterval(10800))
    for s in [s1, s2, s3] {
        try await repos.sessions.schedule(s, attaching: [])
    }
    try await repos.sessions.setStatus(id: s2.id, .cancelled)

    let upcoming = try await repos.sessions.upcoming(after: now, limit: 10)
    #expect(upcoming.map(\.id) == [s1.id, s3.id])
}
