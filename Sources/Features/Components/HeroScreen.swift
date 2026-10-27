import SwiftUI

/// Centered icon + headline + primary button (lock screen, recovery).
struct HeroScreen<Extra: View>: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    var tint: Color = .secondary
    let primary: (title: String, run: () -> Void)
    @ViewBuilder var extra: () -> Extra
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 44

    init(systemImage: String, title: String, message: String? = nil, tint: Color = .secondary,
         primary: (title: String, run: () -> Void),
         @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.tint = tint
        self.primary = primary
        self.extra = extra
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.Fonts.display(.title2))
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(primary.title, action: primary.run)
                .buttonStyle(.borderedProminent)
            extra()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.surface)
    }
}
