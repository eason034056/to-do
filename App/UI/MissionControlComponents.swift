import SwiftUI
import CoupleTodoCore

enum MissionTheme {
    static let backgroundTop = Color(red: 0.13, green: 0.10, blue: 0.26)
    static let backgroundBottom = Color(red: 0.04, green: 0.06, blue: 0.14)
    static let panelFill = Color.white.opacity(0.08)
    static let panelBorder = Color.white.opacity(0.10)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let success = Color(red: 0.43, green: 0.91, blue: 0.64)
    static let active = Color(red: 0.42, green: 0.71, blue: 1.0)
    static let urgent = Color(red: 1.0, green: 0.52, blue: 0.63)
    static let calm = Color(red: 0.88, green: 0.78, blue: 1.0)
    static let warning = Color(red: 1.0, green: 0.80, blue: 0.35)

    static func accent(for emphasis: MissionEmphasis) -> Color {
        switch emphasis {
        case .urgent:
            return urgent
        case .active:
            return active
        case .success:
            return success
        case .calm:
            return calm
        }
    }
}

struct MissionScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [MissionTheme.backgroundTop, MissionTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                content
            }
        }
    }
}

struct MissionPanel<Content: View>: View {
    let emphasis: MissionEmphasis
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MissionTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MissionTheme.accent(for: emphasis).opacity(0.35), lineWidth: 1)
                )
        )
    }
}

struct MissionBadge: View {
    let text: String
    let emphasis: MissionEmphasis

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(MissionTheme.backgroundBottom)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MissionTheme.accent(for: emphasis))
            .clipShape(Capsule())
    }
}

struct MissionMetricBadge: View {
    let text: String
    let emphasis: MissionEmphasis

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MissionTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MissionTheme.accent(for: emphasis).opacity(0.16))
            .overlay(
                Capsule()
                    .stroke(MissionTheme.accent(for: emphasis).opacity(0.45), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct MissionProgressBar: View {
    let value: Double
    let emphasis: MissionEmphasis

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(MissionTheme.accent(for: emphasis))
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: 10)
    }
}

struct MissionPrimaryButtonStyle: ButtonStyle {
    let emphasis: MissionEmphasis

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(MissionTheme.backgroundBottom)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(MissionTheme.accent(for: emphasis).opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct MissionSecondaryButtonStyle: ButtonStyle {
    let emphasis: MissionEmphasis

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(MissionTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(MissionTheme.accent(for: emphasis).opacity(configuration.isPressed ? 0.10 : 0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MissionTheme.accent(for: emphasis).opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MissionMemberPanel: View {
    let content: MissionMemberContent

    var body: some View {
        MissionPanel(emphasis: content.emphasis) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(content.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MissionTheme.textPrimary)
                    Text(content.completionText)
                        .font(.subheadline)
                        .foregroundStyle(MissionTheme.textSecondary)
                }
                Spacer()
                MissionMetricBadge(text: content.planText, emphasis: content.emphasis)
            }

            MissionProgressBar(value: content.progressValue, emphasis: content.emphasis)

            HStack {
                Text(content.highlightText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MissionTheme.textPrimary)
                Spacer()
                Text(content.countdownText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MissionTheme.textSecondary)
            }
        }
    }
}

struct MissionModuleCard: View {
    let content: MissionModuleContent

    var body: some View {
        MissionPanel(emphasis: content.emphasis) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MissionTheme.textPrimary)
                    Text(content.value)
                        .font(.title3.weight(.black))
                        .foregroundStyle(MissionTheme.accent(for: content.emphasis))
                }
                Spacer()
                MissionBadge(text: content.badge, emphasis: content.emphasis)
            }

            Text(content.detail)
                .font(.subheadline)
                .foregroundStyle(MissionTheme.textSecondary)
                .lineLimit(3)
        }
    }
}

struct MissionTaskCard: View {
    let title: String
    let notes: String?
    let emphasis: MissionEmphasis
    let statusText: String
    let trailingText: String
    let symbolName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3.weight(.bold))
                .foregroundStyle(MissionTheme.accent(for: emphasis))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MissionTheme.textPrimary)
                if let notes, notes.isEmpty == false {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(MissionTheme.textSecondary)
                        .lineLimit(2)
                }
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MissionTheme.accent(for: emphasis))
            }

            Spacer(minLength: 12)

            Text(trailingText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MissionTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct MissionSectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(MissionTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(MissionTheme.textSecondary)
        }
    }
}

extension TaskPriority {
    var missionLabel: String {
        rawValue.uppercased()
    }
}
