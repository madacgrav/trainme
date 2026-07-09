import Foundation
import SwiftData

protocol SessionRepository: Sendable {
    /// Schedules a session, deep-copying each attached workout template into a
    /// WorkoutInstance (PRD §4.2: instances are frozen copies).
    func schedule(_ dto: SessionDTO, attaching workoutIds: [UUID]) async throws
    /// Materializes a recurring series as individual sessions sharing a seriesId.
    func scheduleSeries(
        _ dto: SessionDTO,
        recurrence: AppRecurrence,
        attaching workoutIds: [UUID],
        horizonWeeks: Int
    ) async throws
    func get(id: UUID) async throws -> SessionDTO?
    func sessions(from: Date, to: Date) async throws -> [SessionDTO]
    func upcoming(after: Date, limit: Int) async throws -> [SessionDTO]
    func forClient(_ clientId: UUID) async throws -> [SessionDTO]
    func setStatus(id: UUID, _ status: SessionStatus) async throws
    func setEventIdentifier(id: UUID, _ eventIdentifier: String?) async throws
    func updateNotes(id: UUID, _ notes: String?) async throws
    func delete(id: UUID) async throws
}

/// Expands a recurrence rule into concrete occurrence dates. Pure function so
/// scheduling logic is directly unit-testable (no SwiftData involved).
func expandRecurrence(_ rule: AppRecurrence, from start: Date, to horizon: Date) -> [Date] {
    var calendar = Calendar.current
    calendar.firstWeekday = 1 // Sunday, matching EKWeekday numbering
    var dates: [Date] = []
    let maxCount = rule.occurrenceCount ?? Int.max
    let end = rule.endDate.map { min($0, horizon) } ?? horizon

    switch rule.frequency {
    case .daily:
        var current = start
        while current <= end, dates.count < maxCount {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: max(1, rule.interval), to: current) else { break }
            current = next
        }
    case .weekly:
        let weekdays = rule.weekdays.isEmpty
            ? [calendar.component(.weekday, from: start)]
            : rule.weekdays.sorted()
        // Walk week by week from the week containing `start`.
        guard var weekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start else { return [] }
        let timeComponents = calendar.dateComponents([.hour, .minute], from: start)
        outer: while weekStart <= end {
            for weekday in weekdays {
                guard var occurrence = calendar.date(byAdding: .day, value: weekday - 1, to: weekStart) else { continue }
                occurrence = calendar.date(
                    bySettingHour: timeComponents.hour ?? 0,
                    minute: timeComponents.minute ?? 0,
                    second: 0,
                    of: occurrence
                ) ?? occurrence
                if occurrence >= start, occurrence <= end {
                    dates.append(occurrence)
                    if dates.count >= maxCount { break outer }
                }
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: max(1, rule.interval), to: weekStart) else { break }
            weekStart = next
        }
    }
    return dates
}

@ModelActor
actor SwiftDataSessionRepository: SessionRepository {
    func schedule(_ dto: SessionDTO, attaching workoutIds: [UUID]) async throws {
        try insertSession(dto, attaching: workoutIds)
        try modelContext.save()
    }

    func scheduleSeries(
        _ dto: SessionDTO,
        recurrence: AppRecurrence,
        attaching workoutIds: [UUID],
        horizonWeeks: Int = 12
    ) async throws {
        let horizon = Calendar.current.date(byAdding: .weekOfYear, value: horizonWeeks, to: dto.startAt) ?? dto.startAt
        let occurrences = expandRecurrence(recurrence, from: dto.startAt, to: horizon)
        let seriesId = UUID()
        let duration = dto.endAt.timeIntervalSince(dto.startAt)
        let recurrenceData = try? JSONEncoder().encode(recurrence)

        for date in occurrences {
            let occurrence = SessionDTO(
                id: UUID(),
                clientId: dto.clientId,
                startAt: date,
                endAt: date.addingTimeInterval(duration),
                status: .scheduled,
                notes: dto.notes,
                instances: [],
                seriesId: seriesId,
                recurrence: recurrence,
                eventIdentifier: nil,
                createdAt: .now,
                updatedAt: .now
            )
            let model = try insertSession(occurrence, attaching: workoutIds)
            model.recurrenceData = recurrenceData
        }
        try modelContext.save()
    }

    func get(id: UUID) async throws -> SessionDTO? {
        try fetch(id: id).map(SessionDTO.init)
    }

    func sessions(from: Date, to: Date) async throws -> [SessionDTO] {
        try modelContext
            .fetch(FetchDescriptor<Session>(
                predicate: #Predicate { $0.startAt >= from && $0.startAt < to },
                sortBy: [SortDescriptor(\.startAt)]
            ))
            .map(SessionDTO.init)
    }

    func upcoming(after: Date, limit: Int) async throws -> [SessionDTO] {
        let scheduledRaw = SessionStatus.scheduled.rawValue
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.startAt > after && $0.statusRaw == scheduledRaw },
            sortBy: [SortDescriptor(\.startAt)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map(SessionDTO.init)
    }

    func forClient(_ clientId: UUID) async throws -> [SessionDTO] {
        try modelContext
            .fetch(FetchDescriptor<Session>(
                predicate: #Predicate { $0.clientId == clientId },
                sortBy: [SortDescriptor(\.startAt, order: .reverse)]
            ))
            .map(SessionDTO.init)
    }

    func setStatus(id: UUID, _ status: SessionStatus) async throws {
        guard let session = try fetch(id: id) else { return }
        session.statusRaw = status.rawValue
        session.updatedAt = .now
        try modelContext.save()
    }

    func setEventIdentifier(id: UUID, _ eventIdentifier: String?) async throws {
        guard let session = try fetch(id: id) else { return }
        session.eventIdentifier = eventIdentifier
        session.updatedAt = .now
        try modelContext.save()
    }

    func updateNotes(id: UUID, _ notes: String?) async throws {
        guard let session = try fetch(id: id) else { return }
        session.notes = notes
        session.updatedAt = .now
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        guard let session = try fetch(id: id) else { return }
        modelContext.delete(session)
        try modelContext.save()
    }

    // MARK: - Private

    @discardableResult
    private func insertSession(_ dto: SessionDTO, attaching workoutIds: [UUID]) throws -> Session {
        let session = Session(
            id: dto.id,
            clientId: dto.clientId,
            startAt: dto.startAt,
            endAt: dto.endAt,
            status: dto.status,
            notes: dto.notes,
            seriesId: dto.seriesId,
            recurrenceData: dto.recurrence.flatMap { try? JSONEncoder().encode($0) },
            eventIdentifier: dto.eventIdentifier,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
        modelContext.insert(session)

        for workoutId in workoutIds {
            guard let template = try fetchWorkout(id: workoutId) else { continue }
            // COPY the template: the instance is frozen at scheduling time.
            let instance = WorkoutInstance(id: UUID(), sourceWorkoutId: template.id, name: template.name)
            session.instances.append(instance)
            let copied = template.entries
                .sorted { $0.order < $1.order }
                .map { entry in
                    PlannedEntry(
                        id: UUID(),
                        exerciseId: entry.exerciseId,
                        order: entry.order,
                        targetSets: entry.targetSets,
                        targetReps: entry.targetReps,
                        targetWeight: entry.targetWeight,
                        targetDuration: entry.targetDuration
                    )
                }
            instance.plannedEntries.append(contentsOf: copied)
        }
        return session
    }

    private func fetch(id: UUID) throws -> Session? {
        try modelContext.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchWorkout(id: UUID) throws -> Workout? {
        try modelContext.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })).first
    }
}
