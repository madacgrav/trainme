import Foundation
import Observation

@MainActor
@Observable
final class ScheduleViewModel {
    let sessionRepo: any SessionRepository
    let clientRepo: any ClientRepository
    let workoutRepo: any WorkoutRepository
    let exerciseRepo: any ExerciseRepository
    let notifications: any NotificationScheduling

    var selectedDate: Date = .now
    var sessionsForDay: [SessionDTO] = []
    var clientNames: [UUID: String] = [:]
    var clientPhones: [UUID: String] = [:]

    init(
        sessionRepo: any SessionRepository,
        clientRepo: any ClientRepository,
        workoutRepo: any WorkoutRepository,
        exerciseRepo: any ExerciseRepository,
        notifications: any NotificationScheduling
    ) {
        self.sessionRepo = sessionRepo
        self.clientRepo = clientRepo
        self.workoutRepo = workoutRepo
        self.exerciseRepo = exerciseRepo
        self.notifications = notifications
    }

    func load() async {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        sessionsForDay = (try? await sessionRepo.sessions(from: dayStart, to: dayEnd)) ?? []

        let clients = (try? await clientRepo.allIncludingArchived()) ?? []
        clientNames = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.name) })
        clientPhones = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.phoneE164) })

        await rescheduleNotifications()
    }

    /// Keeps pending trainer alerts in sync (nearest-N within the 64 cap).
    func rescheduleNotifications() async {
        let upcoming = (try? await sessionRepo.upcoming(after: .now, limit: 64)) ?? []
        await notifications.reschedule(upcoming: upcoming.map {
            (id: $0.id, startAt: $0.startAt, clientName: clientNames[$0.clientId] ?? "Client")
        })
    }
}
