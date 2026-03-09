import Foundation
import CoupleTodoCore

actor MemoryUserRepository: UserRepository {
    private var storage: [String: UserProfile]

    init(seed: [UserProfile]) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchUser(userId: String) async throws -> UserProfile? {
        storage[userId]
    }

    func upsertUser(_ user: UserProfile) async throws {
        storage[user.id] = user
    }
}

actor MemoryCoupleRepository: CoupleRepository {
    private var storage: [String: Couple]

    init(seed: [Couple]) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchCouple(coupleId: String) async throws -> Couple? {
        storage[coupleId]
    }

    func findCouple(inviteCode: String) async throws -> Couple? {
        storage.values.first(where: { $0.inviteCode == inviteCode })
    }

    func upsertCouple(_ couple: Couple) async throws {
        storage[couple.id] = couple
    }
}

actor MemoryDeviceInstallationRepository: DeviceInstallationRepository {
    private var storage: [String: DeviceInstallation]

    init(seed: [DeviceInstallation]) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchInstallations(userId: String) async throws -> [DeviceInstallation] {
        storage.values.filter { $0.userId == userId }
    }

    func upsertInstallation(_ installation: DeviceInstallation) async throws {
        storage[installation.id] = installation
    }
}

actor MemoryPlanRepository: PlanRepository {
    private var storage: [String: DailyPlan]

    init(seed: [DailyPlan]) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func upsertPlan(_ plan: DailyPlan) async throws {
        storage[plan.id] = plan
    }

    func fetchPlan(userId: String, dateKey: String) async throws -> DailyPlan? {
        storage["\(userId)_\(dateKey)"]
    }
}

actor MemoryTaskRepository: TaskRepository {
    private var storage: [String: [TodoTask]]

    init(seed: [String: [TodoTask]]) {
        storage = seed
    }

    func replaceTasks(for userId: String, dateKey: String, tasks: [TodoTask]) async throws {
        storage[key(userId: userId, dateKey: dateKey)] = tasks
    }

    func fetchTasks(userId: String, dateKey: String) async throws -> [TodoTask] {
        storage[key(userId: userId, dateKey: dateKey)] ?? []
    }

    func upsertTask(_ task: TodoTask) async throws {
        let key = key(userId: task.ownerUserId, dateKey: task.dateKey)
        var tasks = storage[key] ?? []
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        storage[key] = tasks
    }

    func deleteTask(id: String, ownerUserId: String, dateKey: String) async throws {
        storage[key(userId: ownerUserId, dateKey: dateKey)]?.removeAll(where: { $0.id == id })
    }

    private func key(userId: String, dateKey: String) -> String {
        "\(userId)_\(dateKey)"
    }
}

actor MemorySettlementRepository: SettlementRepository {
    private var storage: [String: DailySettlement]

    init(seed: [DailySettlement]) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func upsertSettlement(_ settlement: DailySettlement) async throws {
        storage[settlement.id] = settlement
    }

    func fetchSettlement(coupleId: String, settlementId: String) async throws -> DailySettlement? {
        guard let settlement = storage[settlementId], settlement.coupleId == coupleId else {
            return nil
        }
        return settlement
    }

    func fetchLatestSettlement(coupleId: String, subjectUserId: String) async throws -> DailySettlement? {
        storage.values
            .filter { $0.coupleId == coupleId && $0.subjectUserId == subjectUserId }
            .sorted(by: { $0.computedAt > $1.computedAt })
            .first
    }

    func acknowledgeSettlement(coupleId: String, settlementId: String, userId: String) async throws {
        guard var settlement = storage[settlementId], settlement.coupleId == coupleId else {
            return
        }
        settlement.pendingAcknowledgementUserIds.removeAll { $0 == userId }
        storage[settlementId] = settlement
    }
}

actor MemoryRewardWeekRepository: RewardWeekRepository {
    private var storage: [String: RewardWeek]

    init(seed: [RewardWeek]) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func upsertRewardWeek(_ rewardWeek: RewardWeek) async throws {
        storage[rewardWeek.id] = rewardWeek
    }

    func fetchRewardWeek(coupleId: String, weekKey: String) async throws -> RewardWeek? {
        storage["\(coupleId)_\(weekKey)"]
    }
}

actor MemoryEventRepository: EventRepository {
    private var storage: [EventLogEntry]

    init(seed: [EventLogEntry]) {
        storage = seed
    }

    func appendEvent(_ event: EventLogEntry) async throws {
        storage.append(event)
    }

    func fetchEvents(coupleId: String, limit: Int) async throws -> [EventLogEntry] {
        Array(storage.filter { $0.coupleId == coupleId }.suffix(limit))
    }
}
