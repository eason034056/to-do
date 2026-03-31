import SwiftUI

struct StatusPill: View {
    let text: String
    let emphasis: CoupleTheme.Emphasis

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .fontDesign(.rounded)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(foregroundColor.opacity(0.1))
            )
            .overlay {
                Capsule()
                    .strokeBorder(foregroundColor.opacity(0.15), lineWidth: 0.5)
            }
    }

    private var foregroundColor: Color {
        CoupleTheme.accent(for: emphasis)
    }
}
