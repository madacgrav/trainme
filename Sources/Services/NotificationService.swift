import Foundation
import UserNotifications

/// A planned local-notification alert. Pure value so budgeting is unit-testable.
struct PlannedAlert: Equatable, Sendable {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
}

/// Selects the alerts to schedule: 24h and 1h before each upcoming session,
/// nearest-first, capped so the app never exceeds the iOS 64-pending limit.
/// Pure function — no UNUserNotificationCenter involved.
func selectAlerts(
    sessions: [(id: UUID, startAt: Date, clientName: String)],
    now: Date,
    cap: Int = 64
) -> [PlannedAlert] {
    let maxSessions = cap / 2
    let upcoming = sessions
        .filter { $0.startAt > now }
        .sorted { $0.startAt < $1.startAt }
        .prefix(maxSessions)

    var alerts: [PlannedAlert] = []
    for session in upcoming {
        let time = session.startAt.formatted(date: .omitted, time: .shortened)
        let dayBefore = session.startAt.addingTimeInterval(-24 * 3600)
        if dayBefore > now {
            alerts.append(PlannedAlert(
                identifier: "sess-\(session.id.uuidString)-24h",
                fireDate: dayBefore,
                title: "Session tomorrow",
                body: "\(session.clientName) at \(time)"
            ))
        }
        let hourBefore = session.startAt.addingTimeInterval(-3600)
        if hourBefore > now {
            alerts.append(PlannedAlert(
                identifier: "sess-\(session.id.uuidString)-1h",
                fireDate: hourBefore,
                title: "Session in 1 hour",
                body: "\(session.clientName) at \(time)"
            ))
        }
    }
    return alerts
}

/// Identifiers this app owns. Pure so the filter is unit-testable.
func sessionAlertIdentifiers(from pending: [String]) -> [String] {
    pending.filter { $0.hasPrefix("sess-") }
}

/// Whether alerts may be added for this status. Pure so it is unit-testable.
func canScheduleAlerts(_ status: UNAuthorizationStatus) -> Bool {
    status == .authorized || status == .provisional
}

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    /// Replaces all pending session alerts with the nearest-N set. Skips the
    /// add step unless authorized or provisional (see `canScheduleAlerts`).
    func reschedule(upcoming: [(id: UUID, startAt: Date, clientName: String)]) async
}

final class LocalNotificationService: NotificationScheduling {
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Log.notifications.error("requestAuthorization failed: \(error.localizedDescription)")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func reschedule(upcoming: [(id: UUID, startAt: Date, clientName: String)]) async {
        let center = UNUserNotificationCenter.current()
        // Only touch our own requests; never clobber anything else pending.
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: sessionAlertIdentifiers(from: pending))

        let status = await authorizationStatus()
        guard canScheduleAlerts(status) else {
            Log.notifications.info("Skipping \(upcoming.count) session alerts: authorization status \(status.rawValue)")
            return
        }

        for alert in selectAlerts(sessions: upcoming, now: .now) {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: alert.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(
                    identifier: alert.identifier,
                    content: content,
                    trigger: trigger
                ))
            } catch {
                Log.notifications.error("add \(alert.identifier) failed: \(error.localizedDescription)")
            }
        }
    }
}
