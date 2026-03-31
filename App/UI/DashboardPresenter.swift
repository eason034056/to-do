import Foundation
import CoupleTodoCore

struct HeroContent: Equatable {
    let eyebrow: String
    let title: String
    let subtitle: String
    let primaryActionTitle: String
    let emphasis: CoupleTheme.Emphasis
}

struct MemberStatusContent: Equatable {
    let name: String
    let completionText: String
    let planText: String
    let countdownText: String
    let highlightText: String
    let progressValue: Double
    let emphasis: CoupleTheme.Emphasis
}

struct ModuleContent: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let badge: String
    let emphasis: CoupleTheme.Emphasis
}

enum DashboardPresenter {
    static func hero(for snapshot: DashboardSnapshot) -> HeroContent {
        if let settlement = snapshot.latestSettlement,
           settlement.pendingAcknowledgementUserIds.contains(snapshot.user.id) {
            return HeroContent(
                eyebrow: "Daily Recap",
                title: "Check today's results",
                subtitle: "Your daily wrap-up is ready. Confirm the outcome to keep the streak going.",
                primaryActionTitle: "View Results",
                emphasis: .urgent
            )
        }

        if snapshot.selfSubmittedNextPlan == false {
            let subtitle: String
            if snapshot.partnerSubmittedNextPlan {
                subtitle = "Your partner already planned tomorrow. Time to catch up!"
            } else {
                subtitle = "Set up tomorrow's tasks before the cutoff."
            }

            return HeroContent(
                eyebrow: "Plan Tomorrow",
                title: "What's on for tomorrow?",
                subtitle: subtitle,
                primaryActionTitle: "Plan Now",
                emphasis: .active
            )
        }

        if let payment = snapshot.pendingPayments.first {
            return HeroContent(
                eyebrow: "Payment",
                title: "Payment needs attention",
                subtitle: "A \(payment.currency) \(decimalString(payment.amount)) payment is waiting.",
                primaryActionTitle: "Review Payment",
                emphasis: .urgent
            )
        }

        if let rewardWeek = snapshot.currentRewardWeek, rewardWeek.status == .earned {
            return HeroContent(
                eyebrow: "Reward Earned",
                title: "You did it together!",
                subtitle: rewardWeek.rewardText,
                primaryActionTitle: "See Reward",
                emphasis: .success
            )
        }

        let remaining = snapshot.selfRequired.filter { $0.status != .completed }.count
        let title = remaining == 0 ? "All clear for today!" : "Keep it up!"
        let subtitle = remaining == 0
            ? "All your required tasks are done. Nice work!"
            : "\(remaining) task\(remaining == 1 ? "" : "s") left to finish today."

        return HeroContent(
            eyebrow: "Today",
            title: title,
            subtitle: subtitle,
            primaryActionTitle: "Plan Tomorrow",
            emphasis: remaining == 0 ? .success : .calm
        )
    }

    static func memberContent(
        name: String,
        requiredTasks: [TodoTask],
        submittedNextPlan: Bool,
        planningCountdownMinutes: Int,
        settlementCountdownMinutes: Int
    ) -> MemberStatusContent {
        let completed = requiredTasks.filter { $0.status == .completed }.count
        let total = max(requiredTasks.count, 1)
        let remaining = max(requiredTasks.count - completed, 0)
        let progressValue = requiredTasks.isEmpty ? 1 : Double(completed) / Double(total)

        let completionText: String
        if requiredTasks.isEmpty {
            completionText = "No tasks today"
        } else {
            completionText = "\(completed)/\(requiredTasks.count) done"
        }

        let countdownText: String
        if submittedNextPlan == false {
            countdownText = "Plan in \(planningCountdownMinutes)m"
        } else {
            countdownText = "Recap in \(settlementCountdownMinutes)m"
        }

        let highlightText: String
        if remaining == 0 {
            highlightText = "All done!"
        } else {
            highlightText = "\(remaining) left"
        }

        return MemberStatusContent(
            name: name,
            completionText: completionText,
            planText: submittedNextPlan ? "Planned" : "Not planned",
            countdownText: countdownText,
            highlightText: highlightText,
            progressValue: progressValue,
            emphasis: submittedNextPlan ? (remaining == 0 ? .success : .calm) : .active
        )
    }

    static func modules(for snapshot: DashboardSnapshot) -> [ModuleContent] {
        let selfRemaining = snapshot.selfRequired.filter { $0.status != .completed }.count
        let planningValue = snapshot.selfSubmittedNextPlan ? "Planned" : "Not yet"
        let planningDetail = snapshot.partnerSubmittedNextPlan ? "Partner ready" : "Partner not planned"
        let settlementValue: String
        let settlementDetail: String
        if let settlement = snapshot.latestSettlement {
            settlementValue = settlement.subjectResult.outcome == .pass ? "Passed" : "Penalty"
            settlementDetail = settlement.pendingAcknowledgementUserIds.contains(snapshot.user.id)
                ? "Needs acknowledgement"
                : "All resolved"
        } else {
            settlementValue = "Idle"
            settlementDetail = "Waiting for today's recap"
        }

        let rewardValue = snapshot.currentRewardWeek?.status.rawValue.capitalized ?? "Draft"
        let rewardDetail = snapshot.currentRewardWeek?.rewardText ?? "Pick a weekly reward"
        let paymentValue = snapshot.pendingPayments.isEmpty ? "0" : "\(snapshot.pendingPayments.count)"
        let paymentDetail = snapshot.pendingPayments.isEmpty
            ? "No pending payments"
            : "Needs your attention"

        return [
            ModuleContent(
                id: "planning",
                title: "Tomorrow",
                value: planningValue,
                detail: planningDetail,
                badge: snapshot.planningTargetDateKey,
                emphasis: snapshot.selfSubmittedNextPlan ? .calm : .active
            ),
            ModuleContent(
                id: "today",
                title: "Today",
                value: "\(selfRemaining) left",
                detail: selfRemaining == 0 ? "All tasks done" : "Tasks remaining",
                badge: snapshot.selfContext.dateKey,
                emphasis: selfRemaining == 0 ? .success : .active
            ),
            ModuleContent(
                id: "settlement",
                title: "Daily Recap",
                value: settlementValue,
                detail: settlementDetail,
                badge: snapshot.latestSettlement?.dateKey ?? snapshot.selfContext.dateKey,
                emphasis: settlementDetail.contains("Needs") ? .urgent : .calm
            ),
            ModuleContent(
                id: "reward",
                title: "Weekly Reward",
                value: rewardValue,
                detail: rewardDetail,
                badge: snapshot.currentRewardWeek?.weekKey ?? snapshot.selfContext.weekKey,
                emphasis: snapshot.currentRewardWeek?.status == .earned ? .success : .active
            ),
            ModuleContent(
                id: "payments",
                title: "Payments",
                value: paymentValue,
                detail: paymentDetail,
                badge: snapshot.couple.penaltyPolicy.currency,
                emphasis: snapshot.pendingPayments.isEmpty ? .calm : .urgent
            )
        ]
    }

    static func progressDescription(completed: Int, total: Int) -> String {
        let remaining = total - completed
        if remaining <= 0 {
            return "All done!"
        }
        return "\(remaining) left"
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

enum NotificationCopy {
    static func title(for category: NotificationCategory) -> String {
        switch category {
        case .planningReminder: "Time to plan tomorrow"
        case .planningEscalation: "Last chance to plan!"
        case .settlementReady: "Today's recap is ready"
        case .rewardEarned: "Reward unlocked!"
        case .paymentPending: "Payment needs attention"
        }
    }

    static func body(for category: NotificationCategory) -> String {
        switch category {
        case .planningReminder: "Set up tomorrow's tasks before cutoff."
        case .planningEscalation: "Submit tomorrow's plan now."
        case .settlementReady: "Review today's results together."
        case .rewardEarned: "Your weekly reward is ready to claim."
        case .paymentPending: "A payment update is waiting."
        }
    }

    static func actionTitle(for category: NotificationCategory) -> String {
        switch category {
        case .planningReminder: "Plan Now"
        case .planningEscalation: "Submit Now"
        case .settlementReady: "View Results"
        case .rewardEarned: "See Reward"
        case .paymentPending: "Review"
        }
    }
}
