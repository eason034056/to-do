import SwiftUI
import CoupleTodoCore

struct TodayHeroSection: View {
    let snapshot: DashboardSnapshot
    var selfAvatar: UIImage?
    var partnerAvatar: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
            progressCard
            DeadlineBanner(
                deadlineHour: 10,
                isSubmitted: snapshot.selfSubmittedNextPlan
            )
        }
    }

    private var progressCard: some View {
        let selfCompleted = snapshot.selfRequired.filter { $0.status == .completed }.count
        let selfTotal = max(snapshot.selfRequired.count, 1)
        let selfProgress = snapshot.selfRequired.isEmpty ? 1 : Double(selfCompleted) / Double(selfTotal)
        let selfSubtitle = DashboardPresenter.progressDescription(completed: selfCompleted, total: snapshot.selfRequired.count)

        let partnerCompleted = snapshot.partnerRequired.filter { $0.status == .completed }.count
        let partnerTotal = max(snapshot.partnerRequired.count, 1)
        let partnerProgress = snapshot.partnerRequired.isEmpty ? 1 : Double(partnerCompleted) / Double(partnerTotal)
        let partnerSubtitle = DashboardPresenter.progressDescription(completed: partnerCompleted, total: snapshot.partnerRequired.count)

        return VStack(spacing: 0) {
            AvatarPair(
                youProgress: selfProgress,
                partnerProgress: partnerProgress,
                youSubtitle: selfSubtitle,
                partnerSubtitle: partnerSubtitle,
                youAvatar: selfAvatar,
                partnerAvatar: partnerAvatar
            )
            .padding(CoupleTheme.cardPadding)
        }
        .background(CoupleGradients.heroGradient)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: CoupleTheme.heroCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: CoupleTheme.heroCornerRadius)
                .strokeBorder(CoupleGradients.cardBorderGradient, lineWidth: 0.5)
        }
        .shadow(
            color: CoupleTheme.cardShadowColor,
            radius: CoupleTheme.cardShadowRadius,
            y: CoupleTheme.cardShadowY
        )
    }
}
