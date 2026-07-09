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

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    /// Replaces all pending session alerts with the nearest-N set.
    func reschedule(upcoming: [(id: UUID, startAt: Date, clientName: String)]) async
}

final class LocalNotificationService: NotificationScheduling {
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func reschedule(upcoming: [(id: UUID, startAt: Date, clientName: String)]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

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
            try? await center.add(UNNotificationRequest(
                identifier: alert.identifier,
                content: content,
                trigger: trigger
            ))
        }
    }
}
