import SwiftUI

/// − [value] + with 44pt targets, keyboard entry in the middle.
struct MetricStepper: View {
    let label: String
    @Binding var value: Double
    let step: Double
    var range: ClosedRange<Double> = 0...10_000
    var fractionDigits: Int = 1

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            stepButton("minus", "Decrease \(label)") { value = max(range.lowerBound, value - step) }
            TextField(label, value: $value, format: .number.precision(.fractionLength(0...fractionDigits)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Theme.Fonts.numeric)
                .frame(minWidth: 64, minHeight: 44)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
                .accessibilityLabel(label)
                .accessibilityValue(value.formatted())
            stepButton("plus", "Increase \(label)") { value = min(range.upperBound, value + step) }
        }
    }

    private func stepButton(_ symbol: String, _ a11y: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(a11y)
    }
}

extension Binding where Value == Int? {
    /// Adapts an optional Int to the Double binding MetricStepper needs.
    func asDouble(default d: Double = 0) -> Binding<Double> {
        Binding<Double>(
            get: { Double(self.wrappedValue ?? Int(d)) },
            set: { self.wrappedValue = Int($0.rounded()) }
        )
    }
}

extension Binding where Value == Double? {
    func asDouble(default d: Double = 0) -> Binding<Double> {
        Binding<Double>(get: { self.wrappedValue ?? d }, set: { self.wrappedValue = $0 })
    }
}
