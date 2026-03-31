import SwiftUI
import CoupleTodoCore

enum CoupleTheme {
    // MARK: - Accent

    static let accent = Color(red: 0.25, green: 0.42, blue: 0.52)
    static let accentLight = accent.opacity(0.12)

    // MARK: - You & Partner Identity

    static let youColor = Color(red: 0.82, green: 0.48, blue: 0.45)
    static let partnerColor = Color(red: 0.55, green: 0.48, blue: 0.72)

    // MARK: - Semantic Colors

    static let success = Color(red: 0.35, green: 0.58, blue: 0.42)
    static let active = accent
    static let urgent = Color(red: 0.78, green: 0.28, blue: 0.25)
    static let calm = Color.secondary
    static let warning = Color(red: 0.82, green: 0.62, blue: 0.22)

    static func accent(for emphasis: Emphasis) -> Color {
        switch emphasis {
        case .urgent: urgent
        case .active: accent
        case .success: success
        case .calm: calm
        }
    }

    // MARK: - Spacing

    static let cardCornerRadius: CGFloat = 20
    static let heroCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 12
    static let screenHorizontalPadding: CGFloat = 20
    static let screenBottomPadding: CGFloat = 32

    // MARK: - Shadows

    static let cardShadowColor = Color.black.opacity(0.06)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4

    static let elevatedShadowColor = Color.black.opacity(0.10)
    static let elevatedShadowRadius: CGFloat = 16
    static let elevatedShadowY: CGFloat = 8

    // MARK: - Emphasis Enum

    enum Emphasis: Equatable, Sendable {
        case urgent
        case active
        case success
        case calm
    }
}

// MARK: - Font Presets

extension Font {
    static let sectionTitle: Font = .title3.bold()
    static let cardHeadline: Font = .headline
}

// MARK: - Task Priority

extension TaskPriority {
    var displayLabel: String {
        rawValue.uppercased()
    }

    var color: Color {
        switch self {
        case .p0: CoupleTheme.urgent
        case .p1: CoupleTheme.accent
        case .p2: Color.secondary
        case .p3: Color.secondary.opacity(0.6)
        }
    }
}
