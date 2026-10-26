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

    /// Whether the export-staleness rule fires right now (drives the Settings badge).
    func exportReminderIsDue(defaults: UserDefaults = .standard) async -> Bool {
        let last = defaults.double(forKey: "lastExportAt")
        let lastExport: Date? = last == 0 ? nil : Date(timeIntervalSince1970: last)
        let completed = (try? await sessionRepo.completedCount(since: lastExport)) ?? 0
        return exportReminderDue(lastExportAt: lastExport, now: .now, completedSinceExport: completed)
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
