import Foundation
import Observation

/// Single owner of trainer alerts. Call `refresh()` on foreground and after any
/// session mutation so pending notifications always mirror the store.
@MainActor
@Observable
final class ReminderCoordinator {
    private let sessionRepo: any SessionRepository
    private let clientRepo: any ClientRepository
    private let notifications: any NotificationScheduling

    init(
        sessionRepo: any SessionRepository,
        clientRepo: any ClientRepository,
        notifications: any NotificationScheduling
    ) {
        self.sessionRepo = sessionRepo
        self.clientRepo = clientRepo
        self.notifications = notifications
    }

    func requestAuthorization() async {
        _ = await notifications.requestAuthorization()
    }

    /// Re-plans the nearest-N alerts (the 64-pending budget is enforced in `selectAlerts`).
    func refresh() async {
        let upcoming = (try? await sessionRepo.upcoming(after: .now, limit: 64)) ?? []
        let clients = (try? await clientRepo.allIncludingArchived()) ?? []
        let names = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.name) })
        await notifications.reschedule(upcoming: upcoming.map {
            (id: $0.id, startAt: $0.startAt, clientName: names[$0.clientId] ?? "Client")
        })
    }
}
