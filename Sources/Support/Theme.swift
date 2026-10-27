import SwiftUI

/// Single source of visual identity. Views reference roles, never raw colors.
enum Theme {
    enum Colors {
        static let accent = Color("AccentColor")
        static let brandPrimary = Color("BrandPrimary")
        static let brandSecondary = Color("BrandSecondary")
        static let success = Color("Success")
        static let warning = Color("Warning")
        static let danger = Color("Danger")
        static let personalBest = Color("PersonalBest")
        static let surface = Color("Surface")
        static let surfaceRaised = Color("SurfaceRaised")
    }

    enum Fonts {
        /// Headline-weight rounded display text for row titles and hero copy.
        static func display(_ style: Font.TextStyle = .headline) -> Font {
            .system(style, design: .rounded, weight: .semibold)
        }
        /// Tabular digits for set tables and stat tiles.
        static let numeric: Font = .system(.title3, design: .rounded, weight: .semibold).monospacedDigit()
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
    }

    enum Radius {
        static let row: CGFloat = 12
    }
}

extension View {
    /// Applies the themed surface to a List/Form and hides the system background.
    func themedScreen() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Theme.Colors.surface)
    }

    /// Applies the raised surface to every row in a Section.
    func themedRows() -> some View {
        self.listRowBackground(Theme.Colors.surfaceRaised)
    }
}
