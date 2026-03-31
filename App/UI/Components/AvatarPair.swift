import SwiftUI

struct AvatarPair: View {
    let youProgress: Double
    let partnerProgress: Double
    let youSubtitle: String
    let partnerSubtitle: String
    var youAvatar: UIImage?
    var partnerAvatar: UIImage?

    var body: some View {
        HStack(spacing: 24) {
            avatarColumn(
                label: "You",
                progress: youProgress,
                color: CoupleTheme.youColor,
                subtitle: youSubtitle,
                avatar: youAvatar
            )

            avatarColumn(
                label: "Partner",
                progress: partnerProgress,
                color: CoupleTheme.partnerColor,
                subtitle: partnerSubtitle,
                avatar: partnerAvatar
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func avatarColumn(
        label: String,
        progress: Double,
        color: Color,
        subtitle: String,
        avatar: UIImage?
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: 80, height: 80)

                if let avatar {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(color.opacity(0.25))
                }

                ProgressRing(
                    progress: progress,
                    color: color,
                    size: 80,
                    lineWidth: 4
                )
            }

            Text(label)
                .font(.headline)
                .fontDesign(.rounded)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
