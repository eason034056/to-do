import Foundation
import CoupleTodoCore

enum MissionEmphasis: Equatable {
    case urgent
    case active
    case success
    case calm
}

struct MissionHeroContent: Equatable {
    let eyebrow: String
    let title: String
    let subtitle: String
    let primaryActionTitle: String
    let emphasis: MissionEmphasis
}

struct MissionMemberContent: Equatable {
    let name: String
    let completionText: String
    let planText: String
    let countdownText: String
    let highlightText: String
    let progressValue: Double
    let emphasis: MissionEmphasis
}

struct MissionModuleContent: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let badge: String
    let emphasis: MissionEmphasis
}

enum MissionControlPresentation {
    static func hero(for snapshot: DashboardSnapshot) -> MissionHeroContent {
        if let settlement = snapshot.latestSettlement,
           settlement.pendingAcknowledgementUserIds.contains(snapshot.user.id) {
            return MissionHeroContent(
                eyebrow: "Settlement Alert",
                title: "Resolve today's result",
                subtitle: "Your daily mission is complete. Confirm the settlement to close the loop.",
                primaryActionTitle: "Resolve Settlement",
                emphasis: .urgent
            )
        }

        if snapshot.selfSubmittedNextPlan == false {
            let subtitle: String
            if snapshot.partnerSubmittedNextPlan {
                subtitle = "Your partner is already queued. Load your mission before the window closes."
            } else {
                subtitle = "Build tomorrow's mission loadout before cutoff."
            }

            return MissionHeroContent(
                eyebrow: "Planning Window",
                title: "Load tomorrow's mission",
                subtitle: subtitle,
                primaryActionTitle: "Plan Tomorrow",
                emphasis: .active
            )
        }

        if let payment = snapshot.pendingPayments.first {
            return MissionHeroContent(
                eyebrow: "Payment Queue",
                title: "Review pending payment",
                subtitle: "A \(payment.currency) \(decimalString(payment.amount)) payment is waiting for status confirmation.",
                primaryActionTitle: "Review Payment",
                emphasis: .urgent
            )
        }

        if let rewardWeek = snapshot.currentRewardWeek, rewardWeek.status == .earned {
            return MissionHeroContent(
                eyebrow: "Reward Unlocked",
                title: "Mission streak alive",
                subtitle: rewardWeek.rewardText,
                primaryActionTitle: "Open Reward",
                emphasis: .success
            )
        }

        let remaining = snapshot.selfRequired.filter { $0.status != .completed }.count
        let title = remaining == 0 ? "Board is looking clean" : "Keep the streak moving"
        let subtitle = remaining == 0
            ? "Your required missions are clear. Check on your partner and queue tomorrow."
            : "\(remaining) required mission\(remaining == 1 ? "" : "s") still need your touch today."

        return MissionHeroContent(
            eyebrow: "Mission Board",
            title: title,
            subtitle: subtitle,
            primaryActionTitle: "Open Planning",
            emphasis: remaining == 0 ? .success : .calm
        )
    }

    static func memberContent(
        name: String,
        requiredTasks: [TodoTask],
        submittedNextPlan: Bool,
        planningCountdownMinutes: Int,
        settlementCountdownMinutes: Int
    ) -> MissionMemberContent {
        let completed = requiredTasks.filter { $0.status == .completed }.count
        let total = max(requiredTasks.count, 1)
        let remaining = max(requiredTasks.count - completed, 0)
        let progressValue = requiredTasks.isEmpty ? 1 : Double(completed) / Double(total)

        let completionText: String
        if requiredTasks.isEmpty {
            completionText = "No required missions today"
        } else {
            completionText = "\(completed) of \(requiredTasks.count) required cleared"
        }

        let countdownText: String
        if submittedNextPlan == false {
            countdownText = "Planning in \(planningCountdownMinutes)m"
        } else {
            countdownText = "Settlement in \(settlementCountdownMinutes)m"
        }

        let highlightText: String
        if remaining == 0 {
            highlightText = "All required clear"
        } else {
            highlightText = "\(remaining) mission\(remaining == 1 ? "" : "s") left"
        }

        return MissionMemberContent(
            name: name,
            completionText: completionText,
            planText: submittedNextPlan ? "Tomorrow queued" : "Plan missing",
            countdownText: countdownText,
            highlightText: highlightText,
            progressValue: progressValue,
            emphasis: submittedNextPlan ? (remaining == 0 ? .success : .calm) : .active
        )
    }

    static func modules(for snapshot: DashboardSnapshot) -> [MissionModuleContent] {
        let selfRemaining = snapshot.selfRequired.filter { $0.status != .completed }.count
        let planningValue = snapshot.selfSubmittedNextPlan ? "Queued" : "Missing"
        let planningDetail = snapshot.partnerSubmittedNextPlan ? "Partner ready" : "Partner still drafting"
        let settlementValue: String
        let settlementDetail: String
        if let settlement = snapshot.latestSettlement {
            settlementValue = settlement.subjectResult.outcome == .pass ? "Cleared" : "Penalty"
            settlementDetail = settlement.pendingAcknowledgementUserIds.contains(snapshot.user.id)
                ? "Needs your acknowledgement"
                : "Already resolved"
        } else {
            settlementValue = "Idle"
            settlementDetail = "Waiting for today's settlement"
        }

        let rewardValue = snapshot.currentRewardWeek?.status.rawValue.capitalized ?? "Draft"
        let rewardDetail = snapshot.currentRewardWeek?.rewardText ?? "Pick a weekly reward"
        let paymentValue = snapshot.pendingPayments.isEmpty ? "0" : "\(snapshot.pendingPayments.count)"
        let paymentDetail = snapshot.pendingPayments.isEmpty
            ? "No pending payment reviews"
            : "Action needed on payment status"

        return [
            MissionModuleContent(
                id: "planning",
                title: "Tomorrow Plan",
                value: planningValue,
                detail: planningDetail,
                badge: snapshot.planningTargetDateKey,
                emphasis: snapshot.selfSubmittedNextPlan ? .calm : .active
            ),
            MissionModuleContent(
                id: "today",
                title: "Today's Board",
                value: "\(selfRemaining) left",
                detail: selfRemaining == 0 ? "All required missions are clear" : "Required missions still open",
                badge: snapshot.selfContext.dateKey,
                emphasis: selfRemaining == 0 ? .success : .active
            ),
            MissionModuleContent(
                id: "settlement",
                title: "Settlement",
                value: settlementValue,
                detail: settlementDetail,
                badge: snapshot.latestSettlement?.dateKey ?? snapshot.selfContext.dateKey,
                emphasis: settlementDetail.contains("Needs") ? .urgent : .calm
            ),
            MissionModuleContent(
                id: "reward",
                title: "Reward Bay",
                value: rewardValue,
                detail: rewardDetail,
                badge: snapshot.currentRewardWeek?.weekKey ?? snapshot.selfContext.weekKey,
                emphasis: snapshot.currentRewardWeek?.status == .earned ? .success : .active
            ),
            MissionModuleContent(
                id: "payments",
                title: "Payment Queue",
                value: paymentValue,
                detail: paymentDetail,
                badge: snapshot.couple.penaltyPolicy.currency,
                emphasis: snapshot.pendingPayments.isEmpty ? .calm : .urgent
            )
        ]
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

enum MissionNotificationCopy {
    static func title(for category: NotificationCategory) -> String {
        switch category {
        case .planningReminder:
            return "Mission window open"
        case .planningEscalation:
            return "Final mission call"
        case .settlementReady:
            return "Results ready"
        case .rewardEarned:
            return "Reward unlocked"
        case .paymentPending:
            return "Payment needs review"
        }
    }

    static func body(for category: NotificationCategory) -> String {
        switch category {
        case .planningReminder:
            return "Load tomorrow before cutoff."
        case .planningEscalation:
            return "Submit tomorrow's mission now."
        case .settlementReady:
            return "Review today's settlement."
        case .rewardEarned:
            return "Your weekly reward is live."
        case .paymentPending:
            return "A payment update is waiting."
        }
    }

    static func actionTitle(for category: NotificationCategory) -> String {
        switch category {
        case .planningReminder:
            return "Plan Now"
        case .planningEscalation:
            return "Submit Now"
        case .settlementReady:
            return "Resolve Now"
        case .rewardEarned:
            return "View Reward"
        case .paymentPending:
            return "Review Payment"
        }
    }
}
