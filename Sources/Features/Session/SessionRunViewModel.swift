import Foundation
import Observation

@MainActor
@Observable
final class SessionRunViewModel {
    let sessionRepo: any SessionRepository
    let exerciseRepo: any ExerciseRepository
    private let calendar: any CalendarSyncing
    /// Called after a status change so the presenting screen can refresh its
    /// list and re-plan trainer alerts (a cancelled session must stop alerting).
    private let onStatusChanged: @MainActor () async -> Void
    var session: SessionDTO
    var clientName: String
    var clientPhone: String?
    /// Surfaced at the top of the run screen so the trainer trains safely (PRD §4.4).
    var clientInjuries: String?
    var notesDraft: String
    var exercises: [UUID: ExerciseDTO] = [:]
    var recordedSets: [UUID: [SetRecordDTO]] = [:]  // keyed by instance id

    init(
        sessionRepo: any SessionRepository,
        exerciseRepo: any ExerciseRepository,
        calendar: any CalendarSyncing = EventKitCalendarService(),
        session: SessionDTO,
        clientName: String,
        clientPhone: String? = nil,
        clientInjuries: String? = nil,
        onStatusChanged: @escaping @MainActor () async -> Void = {}
    ) {
        self.sessionRepo = sessionRepo
        self.exerciseRepo = exerciseRepo
        self.calendar = calendar
        self.session = session
        self.clientName = clientName
        self.clientPhone = clientPhone
        self.clientInjuries = clientInjuries
        self.notesDraft = session.notes ?? ""
        self.onStatusChanged = onStatusChanged
    }

    func load() async {
        let all = (try? await exerciseRepo.all()) ?? []
        exercises = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        for instance in session.instances {
            recordedSets[instance.id] = (try? await sessionRepo.setsFor(instanceId: instance.id)) ?? []
        }
        if let refreshed = try? await sessionRepo.get(id: session.id) {
            session = refreshed
            notesDraft = session.notes ?? ""
        }
    }

    func saveNotes() async {
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await sessionRepo.updateNotes(id: session.id, trimmed.isEmpty ? nil : trimmed)
        if let refreshed = try? await sessionRepo.get(id: session.id) {
            session = refreshed
            notesDraft = session.notes ?? ""
        }
    }

    func sets(instanceId: UUID, exerciseId: UUID) -> [SetRecordDTO] {
        (recordedSets[instanceId] ?? []).filter { $0.exerciseId == exerciseId }
    }

    func record(instanceId: UUID, exerciseId: UUID, weight: Double?, reps: Int?, duration: Int?, distance: Double?) async {
        let nextIndex = (sets(instanceId: instanceId, exerciseId: exerciseId).map(\.setIndex).max() ?? -1) + 1
        let dto = SetRecordDTO(
            id: UUID(),
            workoutInstanceId: instanceId,
            exerciseId: exerciseId,
            setIndex: nextIndex,
            weight: weight,
            reps: reps,
            duration: duration,
            distance: distance,
            rpe: nil,
            performedAt: .now,
            createdAt: .now,
            updatedAt: .now
        )
        try? await sessionRepo.recordSet(dto)
        recordedSets[instanceId] = (try? await sessionRepo.setsFor(instanceId: instanceId)) ?? []
    }

    func deleteSet(_ record: SetRecordDTO) async {
        try? await sessionRepo.deleteSet(id: record.id)
        recordedSets[record.workoutInstanceId] = (try? await sessionRepo.setsFor(instanceId: record.workoutInstanceId)) ?? []
    }

    func lastSet(exerciseId: UUID) async -> SetRecordDTO? {
        try? await sessionRepo.lastSet(clientId: session.clientId, exerciseId: exerciseId)
    }

    func setStatus(_ status: SessionStatus) async {
        try? await sessionRepo.setStatus(id: session.id, status)
        // Cancelled sessions leave the system calendar (one-way push cleanup).
        // Series occurrences share one recurring event, so only remove when
        // this session is not part of a series.
        if status == .cancelled, session.seriesId == nil, let eventId = session.eventIdentifier {
            try? await calendar.remove(eventIdentifier: eventId)
            try? await sessionRepo.setEventIdentifier(id: session.id, nil)
        }
        if let refreshed = try? await sessionRepo.get(id: session.id) {
            session = refreshed
        }
        await onStatusChanged()
    }
}
