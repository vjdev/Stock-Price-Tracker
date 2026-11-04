import SwiftUI

/// The visual language for the app. Keep screen-specific styling out of views
/// so the product can be rebranded from one place as it grows.
enum AppTheme {
    enum Colors {
        static let background = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let primaryText = Color(uiColor: .label)
        static let secondaryText = Color(uiColor: .secondaryLabel)
        static let accent = Color(red: 0.12, green: 0.36, blue: 0.92)
        static let positive = Color(red: 0.08, green: 0.58, blue: 0.34)
        static let negative = Color(red: 0.84, green: 0.19, blue: 0.20)
    }

    enum Typography {
        static let screenTitle = Font.largeTitle.weight(.bold)
        static let sectionTitle = Font.title3.weight(.semibold)
        static let body = Font.body
        static let caption = Font.caption
        static let price = Font.title2.weight(.semibold)
    }

    enum Spacing {
        static let compact: CGFloat = 4
        static let row: CGFloat = 6
        static let card: CGFloat = 10
        static let screenPadding: CGFloat = 20
        static let section: CGFloat = 24
        static let item: CGFloat = 12
    }

    enum Radius {
        static let card: CGFloat = 18
    }
}

extension View {
    /// Applies the standard screen background and horizontal insets.
    func appScreenStyle() -> some View {
        background(AppTheme.Colors.background.ignoresSafeArea())
            .padding(.horizontal, AppTheme.Spacing.screenPadding)
    }
}
