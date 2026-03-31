import SwiftUI

struct CelebrationOverlay: View {
    @Binding var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var particles: [ConfettiParticle] = []
    @State private var opacity: Double = 1

    var body: some View {
        if isActive {
            ZStack {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()

                if reduceMotion {
                    staticCelebration
                } else {
                    confettiView
                }

                VStack(spacing: 12) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(CoupleGradients.celebrationGradient)

                    Text("All Done!")
                        .font(.largeTitle.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(CoupleGradients.celebrationGradient)
                }
                .opacity(opacity)
            }
            .task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.4)) {
                    opacity = 0
                }
                try? await Task.sleep(for: .seconds(0.5))
                isActive = false
                opacity = 1
            }
        }
    }

    private var staticCelebration: some View {
        Color.clear
    }

    private var confettiView: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let age = now - particle.birth
                    guard age < 2.5 else { continue }
                    let x = particle.startX + particle.xDrift * sin(age * particle.wobble)
                    let y = particle.startY + age * particle.speed
                    let particleOpacity = max(0, 1 - age / 2.5)
                    let rect = CGRect(x: x, y: y, width: particle.size, height: particle.size)
                    context.opacity = particleOpacity

                    var particleContext = context
                    particleContext.rotate(by: .degrees(particle.rotation + age * 60))

                    if particle.isHeart {
                        let symbol = particleContext.resolve(
                            Image(systemName: "heart.fill")
                        )
                        particleContext.draw(symbol, at: CGPoint(x: x, y: y))
                    } else {
                        particleContext.fill(
                            RoundedRectangle(cornerRadius: 2).path(in: rect),
                            with: .color(particle.color)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .task {
            let now = Date().timeIntervalSinceReferenceDate
            let colors: [Color] = [
                CoupleTheme.success, CoupleTheme.active, CoupleTheme.calm,
                CoupleTheme.youColor, CoupleTheme.partnerColor, CoupleTheme.warning
            ]
            particles = (0..<70).map { _ in
                ConfettiParticle(
                    startX: .random(in: 0...400),
                    startY: .random(in: -80...(-10)),
                    speed: .random(in: 80...220),
                    xDrift: .random(in: 10...50),
                    wobble: .random(in: 2...6),
                    size: .random(in: 4...10),
                    rotation: .random(in: 0...360),
                    isHeart: Bool.random(),
                    color: colors.randomElement() ?? .blue,
                    birth: now + .random(in: 0...0.4)
                )
            }
        }
    }
}

private struct ConfettiParticle {
    let startX: CGFloat
    let startY: CGFloat
    let speed: CGFloat
    let xDrift: CGFloat
    let wobble: CGFloat
    let size: CGFloat
    var rotation: Double = 0
    var isHeart: Bool = false
    let color: Color
    let birth: TimeInterval
}
