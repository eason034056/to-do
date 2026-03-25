import Foundation

public enum DashboardPendingGate: Equatable, Sendable {
    case planning(dateKey: String)
    case settlement(dateKey: String)
}

public struct DashboardSnapshot: Sendable, Equatable {
    public let user: UserProfile
    public let partner: UserProfile
    public let couple: Couple
    public let selfContext: LocalTimeContext
    public let partnerContext: LocalTimeContext
    public let selfRequired: [TodoTask]
    public let selfOptional: [TodoTask]
    public let partnerRequired: [TodoTask]
    public let partnerOptional: [TodoTask]
    public let selfSubmittedNextPlan: Bool
    public let partnerSubmittedNextPlan: Bool
    public let planningTargetDateKey: String
    public let selfPlanningCountdownMinutes: Int
    public let partnerPlanningCountdownMinutes: Int
    public let selfSettlementCountdownMinutes: Int
    public let partnerSettlementCountdownMinutes: Int
    public let latestSettlement: DailySettlement?
    public let currentRewardWeek: RewardWeek?
    public let pendingPayments: [PaymentRecord]
    public let pendingGate: DashboardPendingGate?

    public init(
        user: UserProfile,
        partner: UserProfile,
        couple: Couple,
        selfContext: LocalTimeContext,
        partnerContext: LocalTimeContext,
        selfRequired: [TodoTask],
        selfOptional: [TodoTask],
        partnerRequired: [TodoTask],
        partnerOptional: [TodoTask],
        selfSubmittedNextPlan: Bool,
        partnerSubmittedNextPlan: Bool,
        planningTargetDateKey: String,
        selfPlanningCountdownMinutes: Int,
        partnerPlanningCountdownMinutes: Int,
        selfSettlementCountdownMinutes: Int,
        partnerSettlementCountdownMinutes: Int,
        latestSettlement: DailySettlement?,
        currentRewardWeek: RewardWeek?,
        pendingPayments: [PaymentRecord],
        pendingGate: DashboardPendingGate?
    ) {
        self.user = user
        self.partner = partner
        self.couple = couple
        self.selfContext = selfContext
        self.partnerContext = partnerContext
        self.selfRequired = selfRequired
        self.selfOptional = selfOptional
        self.partnerRequired = partnerRequired
        self.partnerOptional = partnerOptional
        self.selfSubmittedNextPlan = selfSubmittedNextPlan
        self.partnerSubmittedNextPlan = partnerSubmittedNextPlan
        self.planningTargetDateKey = planningTargetDateKey
        self.selfPlanningCountdownMinutes = selfPlanningCountdownMinutes
        self.partnerPlanningCountdownMinutes = partnerPlanningCountdownMinutes
        self.selfSettlementCountdownMinutes = selfSettlementCountdownMinutes
        self.partnerSettlementCountdownMinutes = partnerSettlementCountdownMinutes
        self.latestSettlement = latestSettlement
        self.currentRewardWeek = currentRewardWeek
        self.pendingPayments = pendingPayments
        self.pendingGate = pendingGate
    }
}
