import Foundation

public protocol UserRepository: Sendable {
    func fetchUser(userId: String) async throws -> UserProfile?
    func upsertUser(_ user: UserProfile) async throws
}

public protocol CoupleRepository: Sendable {
    func fetchCouple(coupleId: String) async throws -> Couple?
    func findCouple(inviteCode: String) async throws -> Couple?
    func upsertCouple(_ couple: Couple) async throws
}

public protocol DeviceInstallationRepository: Sendable {
    func fetchInstallations(userId: String) async throws -> [DeviceInstallation]
    func upsertInstallation(_ installation: DeviceInstallation) async throws
}

public protocol PlanRepository: Sendable {
    func upsertPlan(_ plan: DailyPlan) async throws
    func fetchPlan(userId: String, dateKey: String) async throws -> DailyPlan?
}

public protocol TaskRepository: Sendable {
    func replaceTasks(for userId: String, dateKey: String, tasks: [TodoTask]) async throws
    func fetchTasks(userId: String, dateKey: String) async throws -> [TodoTask]
    func upsertTask(_ task: TodoTask) async throws
    func deleteTask(id: String, ownerUserId: String, dateKey: String) async throws
}

public protocol SettlementRepository: Sendable {
    func upsertSettlement(_ settlement: DailySettlement) async throws
    func fetchSettlement(coupleId: String, settlementId: String) async throws -> DailySettlement?
    func fetchLatestSettlement(coupleId: String, subjectUserId: String) async throws -> DailySettlement?
    func acknowledgeSettlement(coupleId: String, settlementId: String, userId: String) async throws
}

public protocol RewardWeekRepository: Sendable {
    func upsertRewardWeek(_ rewardWeek: RewardWeek) async throws
    func fetchRewardWeek(coupleId: String, weekKey: String) async throws -> RewardWeek?
}

public protocol PaymentRepository: Sendable {
    func upsertPayment(_ payment: PaymentRecord) async throws
    func fetchPayment(coupleId: String, recordId: String) async throws -> PaymentRecord?
    func fetchPayments(coupleId: String, userId: String) async throws -> [PaymentRecord]
    func markPaymentPaid(coupleId: String, recordId: String, debtorUserId: String, paidAt: Date) async throws
    func resolvePaymentStatus(
        coupleId: String,
        recordId: String,
        creditorUserId: String,
        status: PaymentStatus,
        resolvedAt: Date
    ) async throws
}

public protocol EventRepository: Sendable {
    func appendEvent(_ event: EventLogEntry) async throws
    func fetchEvents(coupleId: String, limit: Int) async throws -> [EventLogEntry]
}
