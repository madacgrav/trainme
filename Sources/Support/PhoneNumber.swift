import Foundation

/// Normalizes user-entered phone numbers to E.164. Returns nil when the input
/// can't be confidently normalized.
func normalizeE164(_ raw: String, defaultRegion: String = "US") -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let digits = trimmed.filter(\.isNumber)
    guard !digits.isEmpty else { return nil }

    if trimmed.hasPrefix("+") {
        guard (8...15).contains(digits.count) else { return nil }
        return "+" + digits
    }

    guard defaultRegion == "US" else { return nil }
    if digits.count == 10 {
        return "+1" + digits
    }
    if digits.count == 11, digits.first == "1" {
        return "+" + digits
    }
    return nil
}
