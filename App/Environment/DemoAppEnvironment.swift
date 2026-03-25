import Foundation
import CoupleTodoCore
import CoupleTodoFirebase

struct AppEnvironment {
    static let demoCurrentUserId = "usr_self"

    let authService: any AuthenticationService
    let coupleLifecycleGateway: any CoupleLifecycleGateway
    let userRepository: any UserRepository
    let coupleRepository: any CoupleRepository
    let deviceInstallationRepository: any DeviceInstallationRepository
    let planRepository: any PlanRepository
    let taskRepository: any TaskRepository
    let settlementRepository: any SettlementRepository
    let rewardWeekRepository: any RewardWeekRepository
    let paymentRepository: any PaymentRepository
    let eventRepository: any EventRepository
    let sharedSnapshotWriter: SharedSnapshotWriter
    let networkMonitor: any NetworkMonitor
    let nowProvider: () -> Date

    @MainActor
    var profileBootstrapper: UserProfileBootstrapper {
        UserProfileBootstrapper(userRepository: userRepository)
    }

    var loadDashboardUseCase: LoadDashboardUseCase {
        LoadDashboardUseCase(
            userRepository: userRepository,
            coupleRepository: coupleRepository,
            planRepository: planRepository,
            taskRepository: taskRepository,
            settlementRepository: settlementRepository,
            rewardWeekRepository: rewardWeekRepository,
            paymentRepository: paymentRepository
        )
    }

    var submitNextDayPlanUseCase: SubmitNextDayPlanUseCase {
        SubmitNextDayPlanUseCase(planRepository: planRepository, taskRepository: taskRepository)
    }

    var createTaskUseCase: CreateTaskUseCase {
        CreateTaskUseCase(
            taskRepository: taskRepository,
            settlementRepository: settlementRepository,
            eventRepository: eventRepository
        )
    }

    var updateTaskUseCase: UpdateTaskUseCase {
        UpdateTaskUseCase(
            taskRepository: taskRepository,
            settlementRepository: settlementRepository,
            eventRepository: eventRepository
        )
    }

    var deleteTaskUseCase: DeleteTaskUseCase {
        DeleteTaskUseCase(
            taskRepository: taskRepository,
            settlementRepository: settlementRepository,
            eventRepository: eventRepository
        )
    }

    var toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase {
        ToggleTaskCompletionUseCase(
            taskRepository: taskRepository,
            settlementRepository: settlementRepository,
            eventRepository: eventRepository
        )
    }

    var reorderTasksUseCase: ReorderTasksUseCase {
        ReorderTasksUseCase(
            taskRepository: taskRepository,
            settlementRepository: settlementRepository,
            eventRepository: eventRepository
        )
    }

    var acknowledgeSettlementUseCase: AcknowledgeSettlementUseCase {
        AcknowledgeSettlementUseCase(settlementRepository: settlementRepository)
    }

    var saveNextWeekRewardUseCase: SaveNextWeekRewardUseCase {
        SaveNextWeekRewardUseCase(
            coupleRepository: coupleRepository,
            rewardWeekRepository: rewardWeekRepository,
            eventRepository: eventRepository
        )
    }

    var markPlanningMissedUseCase: MarkPlanningMissedUseCase {
        MarkPlanningMissedUseCase(planRepository: planRepository, eventRepository: eventRepository)
    }

    var markPaymentPaidUseCase: MarkPaymentPaidUseCase {
        MarkPaymentPaidUseCase(paymentRepository: paymentRepository)
    }

    var resolvePaymentStatusUseCase: ResolvePaymentStatusUseCase {
        ResolvePaymentStatusUseCase(paymentRepository: paymentRepository)
    }

    func now() -> Date {
        nowProvider()
    }

    @MainActor
    static func live() -> AppEnvironment {
        let services = FirebaseAppServices.live()
        return AppEnvironment(
            authService: services.authService,
            coupleLifecycleGateway: services.coupleLifecycleGateway,
            userRepository: services.userRepository,
            coupleRepository: services.coupleRepository,
            deviceInstallationRepository: services.deviceInstallationRepository,
            planRepository: services.planRepository,
            taskRepository: services.taskRepository,
            settlementRepository: services.settlementRepository,
            rewardWeekRepository: services.rewardWeekRepository,
            paymentRepository: services.paymentRepository,
            eventRepository: services.eventRepository,
            sharedSnapshotWriter: SharedSnapshotWriter(),
            networkMonitor: NWPathNetworkMonitor(),
            nowProvider: Date.init
        )
    }

    @MainActor
    static func demo() -> AppEnvironment {
        let now = Date()
        let selfTimezone = TimeZone(identifier: "America/Chicago") ?? .current
        let partnerTimezone = TimeZone(identifier: "Asia/Tokyo") ?? .current

        let selfContext = LocalTimeContextFactory.make(from: now, timezone: selfTimezone)
        let partnerContext = LocalTimeContextFactory.make(from: now, timezone: partnerTimezone)
        let selfNextDateKey = LocalTimeContextFactory.nextDateKey(from: now, timezone: selfTimezone)
        let partnerNextDateKey = LocalTimeContextFactory.nextDateKey(from: now, timezone: partnerTimezone)
        let currentWeekKey = selfContext.weekKey

        let users = [
            UserProfile(
                id: demoCurrentUserId,
                displayName: "W",
                coupleId: "cpl_demo",
                currentTimezone: selfTimezone.identifier,
                currentUtcOffsetMinutes: selfContext.utcOffsetMinutes,
                lastLocalDateKey: selfContext.dateKey,
                lastLocalWeekKey: selfContext.weekKey,
                createdAt: now,
                updatedAt: now
            ),
            UserProfile(
                id: "usr_partner",
                displayName: "P",
                coupleId: "cpl_demo",
                currentTimezone: partnerTimezone.identifier,
                currentUtcOffsetMinutes: partnerContext.utcOffsetMinutes,
                lastLocalDateKey: partnerContext.dateKey,
                lastLocalWeekKey: partnerContext.weekKey,
                createdAt: now,
                updatedAt: now
            )
        ]

        let couple = Couple(
            id: "cpl_demo",
            memberIds: [demoCurrentUserId, "usr_partner"],
            status: .active,
            weekStartsOn: .monday,
            penaltyPolicy: .default,
            reminderConfig: .default,
            inviteCode: "DEMO42",
            createdAt: now,
            updatedAt: now
        )

        let plans = [
            DailyPlan(
                id: "usr_partner_\(partnerNextDateKey)",
                userId: "usr_partner",
                coupleId: "cpl_demo",
                dateKey: partnerNextDateKey,
                localTimezone: partnerTimezone.identifier,
                submittedAt: now,
                planningMissed: false,
                localUtcOffsetMinutes: partnerContext.utcOffsetMinutes,
                lastEditedAt: now,
                requiredCount: 1,
                optionalCount: 1
            )
        ]

        let tasks: [String: [TodoTask]] = [
            "\(demoCurrentUserId)_\(selfContext.dateKey)": [
                TodoTask(
                    id: "task_self_required",
                    ownerUserId: demoCurrentUserId,
                    dateKey: selfContext.dateKey,
                    localTimezone: selfTimezone.identifier,
                    title: "Ship domain foundation",
                    notes: "Finish core models and routing",
                    bucket: .required,
                    priority: .p0,
                    status: .pending,
                    sortOrder: 1000,
                    completedAtServer: nil,
                    createdAt: now,
                    updatedAt: now
                ),
                TodoTask(
                    id: "task_self_optional",
                    ownerUserId: demoCurrentUserId,
                    dateKey: selfContext.dateKey,
                    localTimezone: selfTimezone.identifier,
                    title: "Refine widget snapshot copy",
                    notes: nil,
                    bucket: .optional,
                    priority: .p2,
                    status: .pending,
                    sortOrder: 2000,
                    completedAtServer: nil,
                    createdAt: now,
                    updatedAt: now
                )
            ],
            "usr_partner_\(partnerContext.dateKey)": [
                TodoTask(
                    id: "task_partner_required",
                    ownerUserId: "usr_partner",
                    dateKey: partnerContext.dateKey,
                    localTimezone: partnerTimezone.identifier,
                    title: "30 minute workout",
                    notes: nil,
                    bucket: .required,
                    priority: .p1,
                    status: .completed,
                    sortOrder: 1000,
                    completedAtServer: now,
                    createdAt: now,
                    updatedAt: now
                ),
                TodoTask(
                    id: "task_partner_optional",
                    ownerUserId: "usr_partner",
                    dateKey: partnerContext.dateKey,
                    localTimezone: partnerTimezone.identifier,
                    title: "Reply to emails",
                    notes: nil,
                    bucket: .optional,
                    priority: .p2,
                    status: .pending,
                    sortOrder: 2000,
                    completedAtServer: nil,
                    createdAt: now,
                    updatedAt: now
                )
            ],
            "\(demoCurrentUserId)_\(selfNextDateKey)": [
                TodoTask(
                    id: "task_plan_required",
                    ownerUserId: demoCurrentUserId,
                    dateKey: selfNextDateKey,
                    localTimezone: selfTimezone.identifier,
                    title: "Plan tomorrow's must-do",
                    notes: nil,
                    bucket: .required,
                    priority: .p0,
                    status: .pending,
                    sortOrder: 1000,
                    completedAtServer: nil,
                    createdAt: now,
                    updatedAt: now
                ),
                TodoTask(
                    id: "task_plan_optional",
                    ownerUserId: demoCurrentUserId,
                    dateKey: selfNextDateKey,
                    localTimezone: selfTimezone.identifier,
                    title: "Optional backlog cleanup",
                    notes: nil,
                    bucket: .optional,
                    priority: .p2,
                    status: .pending,
                    sortOrder: 2000,
                    completedAtServer: nil,
                    createdAt: now,
                    updatedAt: now
                )
            ]
        ]

        let settlements = [
            DailySettlement(
                id: "\(demoCurrentUserId)_\(selfContext.dateKey)",
                coupleId: "cpl_demo",
                subjectUserId: demoCurrentUserId,
                counterpartyUserId: "usr_partner",
                dateKey: selfContext.dateKey,
                localTimezone: selfTimezone.identifier,
                localWeekKey: selfContext.weekKey,
                state: .finalized,
                computedAt: now,
                graceAppliedUntil: now,
                subjectResult: SettlementResult(
                    requiredTotal: 3,
                    requiredCompleted: 2,
                    missedRequiredCount: 1,
                    outcome: .fail,
                    owesAmount: 50
                ),
                counterpartySnapshot: CounterpartySettlementSnapshot(
                    latestKnownDateKey: partnerContext.dateKey,
                    latestKnownOutcome: .pass
                ),
                pendingAcknowledgementUserIds: [demoCurrentUserId],
                rewardImpact: RewardImpact(weekKey: selfContext.weekKey, stillEligible: false)
            )
        ]

        let rewardWeeks = [
            RewardWeek(
                id: "cpl_demo_\(currentWeekKey)",
                coupleId: "cpl_demo",
                weekKey: currentWeekKey,
                effectiveWeekStartDate: LocalTimeContextFactory.dateKey(
                    from: LocalTimeContextFactory.startOfWeek(from: now, weekStartsOn: .monday, timezone: selfTimezone),
                    timezone: selfTimezone
                ),
                draftedInWeekKey: LocalTimeContextFactory.weekKey(
                    from: Calendar(identifier: .iso8601).date(byAdding: .day, value: -7, to: now) ?? now,
                    timezone: selfTimezone
                ),
                rewardText: "Saturday brunch if both stay green",
                status: .active,
                eligibility: [demoCurrentUserId: false, "usr_partner": true],
                memberLocalWeekKeys: [demoCurrentUserId: currentWeekKey, "usr_partner": partnerContext.weekKey],
                updatedAt: now
            )
        ]

        let userRepository = MemoryUserRepository(seed: users)
        let coupleRepository = MemoryCoupleRepository(seed: [couple])

        return AppEnvironment(
            authService: DemoAuthenticationService(userId: demoCurrentUserId),
            coupleLifecycleGateway: DemoCoupleLifecycleGateway(
                userRepository: userRepository,
                coupleRepository: coupleRepository
            ),
            userRepository: userRepository,
            coupleRepository: coupleRepository,
            deviceInstallationRepository: MemoryDeviceInstallationRepository(seed: []),
            planRepository: MemoryPlanRepository(seed: plans),
            taskRepository: MemoryTaskRepository(seed: tasks),
            settlementRepository: MemorySettlementRepository(seed: settlements),
            rewardWeekRepository: MemoryRewardWeekRepository(seed: rewardWeeks),
            paymentRepository: MemoryPaymentRepository(seed: []),
            eventRepository: MemoryEventRepository(seed: []),
            sharedSnapshotWriter: SharedSnapshotWriter(),
            networkMonitor: StubNetworkMonitor(),
            nowProvider: Date.init
        )
    }
}

@MainActor
private final class DemoAuthenticationService: AuthenticationService {
    private let session: AuthSession

    init(userId: String) {
        session = AuthSession(userId: userId, displayName: "Demo User")
    }

    func currentSession() -> AuthSession? {
        session
    }

    func signIn(with provider: AuthenticationProvider) async throws -> AuthSession {
        session
    }

    func handleOpenURL(_ url: URL) -> Bool {
        false
    }

    func signOut() throws {}
}

@MainActor
private final class DemoCoupleLifecycleGateway: CoupleLifecycleGateway {
    private let userRepository: any UserRepository
    private let coupleRepository: any CoupleRepository

    init(userRepository: any UserRepository, coupleRepository: any CoupleRepository) {
        self.userRepository = userRepository
        self.coupleRepository = coupleRepository
    }

    func createCouple(
        weekStartsOn: WeekStart,
        reminderConfig: ReminderConfig,
        penaltyPolicy: PenaltyPolicy
    ) async throws -> PairingResult {
        guard let session = DemoAuthenticationService(userId: AppEnvironment.demoCurrentUserId).currentSession() else {
            return PairingResult(coupleId: "", memberIds: [], status: .pending, inviteCode: nil)
        }
        let result = try await CreateCoupleUseCase(
            userRepository: userRepository,
            coupleRepository: coupleRepository
        ).execute(
            CreateCoupleRequest(
                creatorUserId: session.userId,
                now: Date(),
                weekStartsOn: weekStartsOn,
                penaltyPolicy: penaltyPolicy,
                reminderConfig: reminderConfig
            )
        )
        return PairingResult(
            coupleId: result.couple.id,
            memberIds: result.couple.memberIds,
            status: result.couple.status,
            inviteCode: result.inviteCode
        )
    }

    func joinCouple(inviteCode: String) async throws -> PairingResult {
        let couple = try await JoinCoupleUseCase(
            userRepository: userRepository,
            coupleRepository: coupleRepository
        ).execute(
            JoinCoupleRequest(
                userId: AppEnvironment.demoCurrentUserId,
                inviteCode: inviteCode,
                now: Date()
            )
        )
        return PairingResult(
            coupleId: couple.id,
            memberIds: couple.memberIds,
            status: couple.status,
            inviteCode: couple.inviteCode
        )
    }
}
