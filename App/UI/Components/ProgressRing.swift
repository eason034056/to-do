import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    @State private var animatedProgress: Double = 0

    init(progress: Double, color: Color, size: CGFloat = 64, lineWidth: CGFloat = 6) {
        self.progress = progress
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: lineWidth + 1)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.6), color, color.opacity(0.8)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.3), radius: 3)

            if animatedProgress > 0.02 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth + 2, height: lineWidth + 2)
                    .shadow(color: color.opacity(0.5), radius: 2)
                    .offset(y: -(size / 2))
                    .rotationEffect(.degrees(360 * animatedProgress))
            }
        }
        .frame(width: size, height: size)
        .task {
            withAnimation(CoupleAnimations.progressFill) {
                animatedProgress = min(max(progress, 0), 1)
            }
        }
        .onChange(of: progress) {
            withAnimation(CoupleAnimations.progressFill) {
                animatedProgress = min(max(progress, 0), 1)
            }
        }
    }
}
