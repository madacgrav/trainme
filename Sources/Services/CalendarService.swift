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

enum CalendarError: Error, Equatable {
    /// No default calendar and no calendar that allows modifications.
    case noWritableCalendar
}

protocol CalendarSyncing: Sendable {
    func requestAccess() async -> Bool
    func authorizationStatus() async -> EKAuthorizationStatus
    /// One-way push to the default calendar. Returns the eventIdentifier to
    /// store for later update/removal.
    func push(_ session: SessionDTO, clientName: String, recurrence: AppRecurrence?) async throws -> String?
    /// Edits the pushed event in place. Returns the identifier to store: the
    /// same one, a new one if the event had vanished and was re-pushed, or nil
    /// without calendar access.
    func update(eventIdentifier: String, _ session: SessionDTO, clientName: String) async throws -> String?
    func remove(eventIdentifier: String) async throws
}

actor EventKitCalendarService: CalendarSyncing {
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            Log.calendar.error("requestFullAccessToEvents failed: \(error.localizedDescription)")
            return false
        }
    }

    func authorizationStatus() async -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// The default calendar when the user has one, otherwise the first calendar
    /// that accepts new events. Throws when neither exists.
    private func writableCalendar() throws -> EKCalendar {
        if let preferred = store.defaultCalendarForNewEvents { return preferred }
        if let fallback = store.calendars(for: .event).first(where: { $0.allowsContentModifications }) {
            Log.calendar.info("No default calendar; using \(fallback.title)")
            return fallback
        }
        throw CalendarError.noWritableCalendar
    }

    func push(_ session: SessionDTO, clientName: String, recurrence: AppRecurrence?) async throws -> String? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let event = EKEvent(eventStore: store)
        event.title = "Training: \(clientName)"
        event.startDate = session.startAt
        event.endDate = session.endAt
        event.notes = session.notes
        event.calendar = try writableCalendar()
        if let recurrence {
            event.recurrenceRules = [makeEKRecurrenceRule(recurrence)]
        }
        try store.save(event, span: .futureEvents, commit: true)
        return event.eventIdentifier
    }

    func update(eventIdentifier: String, _ session: SessionDTO, clientName: String) async throws -> String? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        guard let event = store.event(withIdentifier: eventIdentifier) else {
            // The user deleted or moved it; re-create so the calendar matches the app.
            return try await push(session, clientName: clientName, recurrence: nil)
        }
        event.title = "Training: \(clientName)"
        event.startDate = session.startAt
        event.endDate = session.endAt
        event.notes = session.notes
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    func remove(eventIdentifier: String) async throws {
        guard let event = store.event(withIdentifier: eventIdentifier) else { return }
        try store.remove(event, span: .futureEvents, commit: true)
    }
}
