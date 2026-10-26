import Foundation

struct PlannedEntryDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var exerciseId: UUID
    var order: Int
    var targetSets: Int?
    var targetReps: Int?
    var targetWeight: Double?
    var targetDuration: Int?
}

struct WorkoutInstanceDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var sourceWorkoutId: UUID
    var name: String
    var plannedEntries: [PlannedEntryDTO]
}

struct SessionDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var clientId: UUID
    var startAt: Date
    var endAt: Date
    var status: SessionStatus
    var notes: String?
    var instances: [WorkoutInstanceDTO]
    var seriesId: UUID?
    var recurrence: AppRecurrence?
    var eventIdentifier: String?
    var createdAt: Date
    var updatedAt: Date
}

extension PlannedEntryDTO {
    init(_ model: PlannedEntry) {
        self.init(
            id: model.id,
            exerciseId: model.exerciseId,
            order: model.order,
            targetSets: model.targetSets,
            targetReps: model.targetReps,
            targetWeight: model.targetWeight,
            targetDuration: model.targetDuration
        )
    }

    func toModel() -> PlannedEntry {
        PlannedEntry(
            id: id,
            exerciseId: exerciseId,
            order: order,
            targetSets: targetSets,
            targetReps: targetReps,
            targetWeight: targetWeight,
            targetDuration: targetDuration
        )
    }
}

extension WorkoutInstanceDTO {
    init(_ model: WorkoutInstance) {
        self.init(
            id: model.id,
            sourceWorkoutId: model.sourceWorkoutId,
            name: model.name,
            plannedEntries: model.plannedEntries.sorted { $0.order < $1.order }.map(PlannedEntryDTO.init)
        )
    }
}

extension SessionDTO {
    init(_ model: Session) {
        self.init(
            id: model.id,
            clientId: model.clientId,
            startAt: model.startAt,
            endAt: model.endAt,
            status: model.status,
            notes: model.notes,
            instances: model.instances.map(WorkoutInstanceDTO.init),
            seriesId: model.seriesId,
            recurrence: model.recurrenceData.flatMap { try? JSONDecoder().decode(AppRecurrence.self, from: $0) },
            eventIdentifier: model.eventIdentifier,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
}

extension WorkoutInstanceDTO {
    /// Builds a WorkoutInstance with its planned entries attached.
    func toModel() -> WorkoutInstance {
        let instance = WorkoutInstance(id: id, sourceWorkoutId: sourceWorkoutId, name: name)
        instance.plannedEntries.append(contentsOf: plannedEntries.map { $0.toModel() })
        return instance
    }
}

extension SessionDTO {
    /// Builds a Session with its instances attached; mirrors SessionRepository.insertSession.
    func toModel() -> Session {
        let session = Session(
            id: id,
            clientId: clientId,
            startAt: startAt,
            endAt: endAt,
            status: status,
            notes: notes,
            seriesId: seriesId,
            recurrenceData: recurrence.flatMap { try? JSONEncoder().encode($0) },
            eventIdentifier: eventIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        session.instances.append(contentsOf: instances.map { $0.toModel() })
        return session
    }
}
