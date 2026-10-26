import SwiftUI

/// Title over an optional caption and tertiary line, with an optional trailing view.
struct TitleCaptionRow<Trailing: View>: View {
    let title: String
    var caption: String? = nil
    var tertiary: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, caption: String? = nil, tertiary: String? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.caption = caption
        self.tertiary = tertiary
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Fonts.display()).foregroundStyle(.primary)
                if let caption, !caption.isEmpty {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
                if let tertiary, !tertiary.isEmpty {
                    Text(tertiary).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .accessibilityElement(children: .combine)
    }
}
