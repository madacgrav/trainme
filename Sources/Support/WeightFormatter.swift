import Foundation

/// All weight strings in the app go through here (PRD §4.5). The exercise's
/// `defaultUnit` is the unit of record; nothing is ever converted.
enum WeightFormatter {
    static func string(_ value: Double, unit: Unit) -> String {
        "\(value.formatted()) \(label(unit))"
    }

    /// "lb" / "kg"; any non-weight unit falls back to "lb" so a mis-set
    /// exercise never labels a weight in miles.
    static func label(_ unit: Unit) -> String {
        switch unit {
        case .kg: "kg"
        default: "lb"
        }
    }

    /// "12,450 lb · 300 kg"; units with no volume are omitted; "—" when nothing.
    static func volumeString(_ totals: VolumeTotals) -> String {
        let parts = [Unit.lb, .kg].compactMap { unit -> String? in
            guard let amount = totals.byUnit[unit], amount > 0 else { return nil }
            return string(amount, unit: unit)
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    static func stepIncrement(for unit: Unit) -> Double {
        unit == .kg ? 2.5 : 5
    }
}
