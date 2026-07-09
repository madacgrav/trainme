import Foundation
import Observation

@MainActor
@Observable
final class SessionRunViewModel {
    let sessionRepo: any SessionRepository
    let exerciseRepo: any ExerciseRepository
    var session: SessionDTO
    var clientName: String
    var clientPhone: String?
    var exercises: [UUID: ExerciseDTO] = [:]
    var recordedSets: [UUID: [SetRecordDTO]] = [:]  // keyed by instance id

    init(
        sessionRepo: any SessionRepository,
        exerciseRepo: any ExerciseRepository,
        session: SessionDTO,
        clientName: String,
        clientPhone: String? = nil
    ) {
        self.sessionRepo = sessionRepo
        self.exerciseRepo = exerciseRepo
        self.session = session
        self.clientName = clientName
        self.clientPhone = clientPhone
    }

    func load() async {
        let all = (try? await exerciseRepo.all()) ?? []
        exercises = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        for instance in session.instances {
            recordedSets[instance.id] = (try? await sessionRepo.setsFor(instanceId: instance.id)) ?? []
        }
        if let refreshed = try? await sessionRepo.get(id: session.id) {
            session = refreshed
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
        if let refreshed = try? await sessionRepo.get(id: session.id) {
            session = refreshed
        }
    }
}
