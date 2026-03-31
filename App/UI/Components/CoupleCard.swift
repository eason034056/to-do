import SwiftUI

struct CoupleCard<Content: View>: View {
    let emphasis: CoupleTheme.Emphasis
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            if emphasis == .urgent || emphasis == .active {
                RoundedRectangle(cornerRadius: 2)
                    .fill(CoupleTheme.accent(for: emphasis))
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }

            VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
                content
            }
            .padding(CoupleTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.regularMaterial)
        .background(emphasisTint)
        .clipShape(.rect(cornerRadius: CoupleTheme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: CoupleTheme.cardCornerRadius)
                .strokeBorder(CoupleGradients.cardBorderGradient, lineWidth: 0.5)
        }
        .shadow(
            color: CoupleTheme.cardShadowColor,
            radius: CoupleTheme.cardShadowRadius,
            y: CoupleTheme.cardShadowY
        )
    }

    private var emphasisTint: Color {
        switch emphasis {
        case .urgent: CoupleTheme.urgent.opacity(0.04)
        case .success: CoupleTheme.success.opacity(0.04)
        case .active: CoupleTheme.accent.opacity(0.03)
        case .calm: .clear
        }
    }
}
