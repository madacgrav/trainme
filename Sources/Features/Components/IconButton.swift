import SwiftUI

/// Icon-only button that always carries a VoiceOver label and a 44pt target.
struct IconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var role: ButtonRole? = nil
    let tint: AnyShapeStyle
    let action: () -> Void

    init(title: LocalizedStringKey, systemImage: String, role: ButtonRole? = nil,
         tint: some ShapeStyle = HierarchicalShapeStyle.secondary, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.tint = AnyShapeStyle(tint)
        self.action = action
    }

    var body: some View {
        Button(title, systemImage: systemImage, role: role, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(title))
    }
}
