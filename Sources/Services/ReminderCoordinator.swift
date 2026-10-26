import Foundation
import Observation
import UserNotifications

/// Single owner of trainer alerts. Call `refresh()` on foreground and after any
/// session mutation so pending notifications always mirror the store.
@MainActor
@Observable
final class ReminderCoordinator {
    private let sessionRepo: any SessionRepository
    private let clientRepo: any ClientRepository
    private let notifications: any NotificationScheduling
    /// Mirrors the system notification permission so Settings can show it.
    private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

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
        let granted = await notifications.requestAuthorization()
        notificationStatus = await notifications.authorizationStatus()
        Log.notifications.info("Notification authorization granted=\(granted) status=\(self.notificationStatus.rawValue)")
    }

    func refreshPermissionStatus() async {
        notificationStatus = await notifications.authorizationStatus()
    }

    /// Whether the export-staleness rule fires right now (drives the Settings badge).
    func exportReminderIsDue(defaults: UserDefaults = .standard) async -> Bool {
        let last = defaults.double(forKey: "lastExportAt")
        let lastExport: Date? = last == 0 ? nil : Date(timeIntervalSince1970: last)
        let completed: Int
        do {
            completed = try await sessionRepo.completedCount(since: lastExport)
        } catch {
            Log.notifications.debug("completedCount failed: \(error.localizedDescription)")
            completed = 0
        }
        return exportReminderDue(lastExportAt: lastExport, now: .now, completedSinceExport: completed)
    }

    /// Re-plans the nearest-N alerts (the 64-pending budget is enforced in `selectAlerts`).
    func refresh() async {
        let upcoming: [SessionDTO]
        do {
            upcoming = try await sessionRepo.upcoming(after: .now, limit: 64)
        } catch {
            Log.notifications.error("upcoming sessions fetch failed: \(error.localizedDescription)")
            upcoming = []
        }
        let clients: [ClientDTO]
        do {
            clients = try await clientRepo.allIncludingArchived()
        } catch {
            Log.notifications.error("clients fetch failed: \(error.localizedDescription)")
            clients = []
        }
        let names = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.name) })
        await notifications.reschedule(upcoming: upcoming.map {
            (id: $0.id, startAt: $0.startAt, clientName: names[$0.clientId] ?? "Client")
        })
        await refreshPermissionStatus()
    }
}
