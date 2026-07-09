import Foundation
import Observation

@MainActor
@Observable
final class ScheduleViewModel {
    let sessionRepo: any SessionRepository
    let clientRepo: any ClientRepository
    let workoutRepo: any WorkoutRepository
    let exerciseRepo: any ExerciseRepository

    var selectedDate: Date = .now
    var sessionsForDay: [SessionDTO] = []
    var clientNames: [UUID: String] = [:]

    init(
        sessionRepo: any SessionRepository,
        clientRepo: any ClientRepository,
        workoutRepo: any WorkoutRepository,
        exerciseRepo: any ExerciseRepository
    ) {
        self.sessionRepo = sessionRepo
        self.clientRepo = clientRepo
        self.workoutRepo = workoutRepo
        self.exerciseRepo = exerciseRepo
    }

    func load() async {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        sessionsForDay = (try? await sessionRepo.sessions(from: dayStart, to: dayEnd)) ?? []

        let clients = (try? await clientRepo.allIncludingArchived()) ?? []
        clientNames = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.name) })
    }
}
