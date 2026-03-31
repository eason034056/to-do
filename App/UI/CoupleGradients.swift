import SwiftUI

enum CoupleGradients {

    // MARK: - Primary Gradients

    static let accentGradient = LinearGradient(
        colors: [CoupleTheme.accent, CoupleTheme.accent.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [
            CoupleTheme.accent.opacity(0.15),
            CoupleTheme.partnerColor.opacity(0.08),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Member Gradients

    static let youGradient = LinearGradient(
        colors: [CoupleTheme.youColor, CoupleTheme.youColor.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let partnerGradient = LinearGradient(
        colors: [CoupleTheme.partnerColor, CoupleTheme.partnerColor.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Card Border

    static let cardBorderGradient = LinearGradient(
        colors: [
            Color.primary.opacity(0.1),
            Color.primary.opacity(0.04),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Celebration

    static let celebrationGradient = LinearGradient(
        colors: [CoupleTheme.youColor, CoupleTheme.partnerColor, CoupleTheme.success],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Emphasis Gradient

    static func gradient(for emphasis: CoupleTheme.Emphasis) -> LinearGradient {
        let color = CoupleTheme.accent(for: emphasis)
        return LinearGradient(
            colors: [color, color.opacity(0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
