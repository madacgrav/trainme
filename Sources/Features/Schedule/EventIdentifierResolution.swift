import Foundation

/// What to do with the stored event identifier after a save's calendar step.
enum CalendarOutcome: Equatable {
    /// Nothing to persist.
    case unchanged
    /// Persist this identifier (nil clears it).
    case store(String?)
    /// Calendar step failed; keep the existing identifier and warn the user.
    case failed(String)
}

/// Pure decision for SessionEditView. `result` is nil when no calendar call was
/// made (toggle off with nothing to remove, or access denied). A failure never
/// clears a stored identifier: the event may still exist and a later save can
/// retry against it.
func resolveEventIdentifier(
    existing: String?,
    wantsCalendar: Bool,
    hasAccess: Bool,
    result: Result<String?, any Error>?
) -> CalendarOutcome {
    guard wantsCalendar else {
        // Toggle off: `result` is the remove() outcome when an id existed.
        guard existing != nil, let result else { return .unchanged }
        switch result {
        case .success: return .store(nil)
        case .failure: return .failed("Saved, but the calendar event couldn't be removed.")
        }
    }
    guard hasAccess else {
        return existing == nil
            ? .failed("Saved, but calendar access is off. Allow it in Settings to add events.")
            : .unchanged
    }
    switch result {
    case .success(let id?) where id == existing: return .unchanged
    case .success(let id?): return .store(id)
    case .success(nil), .none: return .failed("Saved, but no calendar was available.")
    case .failure(let error):
        if case CalendarError.noWritableCalendar = error {
            return .failed("Saved, but there is no writable calendar on this phone.")
        }
        return .failed("Saved, but the calendar couldn't be updated.")
    }
}

/// Runs an async throwing body and captures its outcome as a Result. Inherits
/// the caller's isolation so a non-Sendable closure never crosses an actor.
func capturing<T>(
    isolation: isolated (any Actor)? = #isolation,
    _ body: () async throws -> T
) async -> Result<T, any Error> {
    do {
        return .success(try await body())
    } catch {
        return .failure(error)
    }
}
