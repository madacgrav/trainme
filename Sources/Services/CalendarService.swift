import EventKit
import Foundation

/// Maps the app's recurrence model to EventKit. Pure function — unit-testable
/// without an event store.
func makeEKRecurrenceRule(_ rule: AppRecurrence) -> EKRecurrenceRule {
    let frequency: EKRecurrenceFrequency = switch rule.frequency {
    case .daily: .daily
    case .weekly: .weekly
    }
    let days: [EKRecurrenceDayOfWeek]? = rule.weekdays.isEmpty
        ? nil
        : rule.weekdays.compactMap { EKWeekday(rawValue: $0).map { EKRecurrenceDayOfWeek($0) } }
    let end: EKRecurrenceEnd? = if let count = rule.occurrenceCount {
        EKRecurrenceEnd(occurrenceCount: count)
    } else if let endDate = rule.endDate {
        EKRecurrenceEnd(end: endDate)
    } else {
        nil
    }
    return EKRecurrenceRule(
        recurrenceWith: frequency,
        interval: max(1, rule.interval),
        daysOfTheWeek: days,
        daysOfTheMonth: nil,
        monthsOfTheYear: nil,
        weeksOfTheYear: nil,
        daysOfTheYear: nil,
        setPositions: nil,
        end: end
    )
}

protocol CalendarSyncing: Sendable {
    func requestAccess() async -> Bool
    /// One-way push to the default calendar. Returns the eventIdentifier to
    /// store for later update/removal.
    func push(_ session: SessionDTO, clientName: String, recurrence: AppRecurrence?) async throws -> String?
    func remove(eventIdentifier: String) async throws
}

actor EventKitCalendarService: CalendarSyncing {
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func push(_ session: SessionDTO, clientName: String, recurrence: AppRecurrence?) async throws -> String? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let event = EKEvent(eventStore: store)
        event.title = "Training: \(clientName)"
        event.startDate = session.startAt
        event.endDate = session.endAt
        event.notes = session.notes
        event.calendar = store.defaultCalendarForNewEvents
        if let recurrence {
            event.recurrenceRules = [makeEKRecurrenceRule(recurrence)]
        }
        try store.save(event, span: .futureEvents, commit: true)
        return event.eventIdentifier
    }

    func remove(eventIdentifier: String) async throws {
        guard let event = store.event(withIdentifier: eventIdentifier) else { return }
        try store.remove(event, span: .futureEvents, commit: true)
    }
}
