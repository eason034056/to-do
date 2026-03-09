import Foundation
import CoupleTodoCore

struct DemoAppEnvironment {
    static let defaultCurrentUserId = "usr_self"

    let userRepository: MemoryUserRepository
    let coupleRepository: MemoryCoupleRepository
    let deviceInstallationRepository: MemoryDeviceInstallationRepository
    let planRepository: MemoryPlanRepository
    let taskRepository: MemoryTaskRepository
    let settlementRepository: MemorySettlementRepository
    let rewardWeekRepository: MemoryRewardWeekRepository
    let eventRepository: MemoryEventRepository
    let sharedSnapshotWriter: SharedSnapshotWriter

    var loadDashboardUseCase: LoadDashboardUseCase {
        LoadDashboardUseCase(
            userRepository: userRepository,
            coupleRepository: coupleRepository,
            planRepository: planRepository,
            taskRepository: taskRepository,
            settlementRepository: settlementRepository,
            rewardWeekRepository: rewardWeekRepository
        )
    }

    var submitNextDayPlanUseCase: SubmitNextDayPlanUseCase {
        SubmitNextDayPlanUseCase(planRepository: planRepository, taskRepository: taskRepository)
    }

    var createTaskUseCase: CreateTaskUseCase {
        CreateTaskUseCase(taskRepository: taskRepository, eventRepository: eventRepository)
    }

    var updateTaskUseCase: UpdateTaskUseCase {
        UpdateTaskUseCase(taskRepository: taskRepository, eventRepository: eventRepository)
    }

    var deleteTaskUseCase: DeleteTaskUseCase {
        DeleteTaskUseCase(taskRepository: taskRepository, eventRepository: eventRepository)
    }

    var toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase {
        ToggleTaskCompletionUseCase(taskRepository: taskRepository, eventRepository: eventRepository)
    }

    var reorderTasksUseCase: ReorderTasksUseCase {
        ReorderTasksUseCase(taskRepository: taskRepository, eventRepository: eventRepository)
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

    func now() -> Date {
        Date()
    }

    static func demo() -> DemoAppEnvironment {
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
                id: defaultCurrentUserId,
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
            memberIds: [defaultCurrentUserId, "usr_partner"],
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
            "\(defaultCurrentUserId)_\(selfContext.dateKey)": [
                TodoTask(
                    id: "task_self_required",
                    ownerUserId: defaultCurrentUserId,
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
                    ownerUserId: defaultCurrentUserId,
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
            "\(defaultCurrentUserId)_\(selfNextDateKey)": [
                TodoTask(
                    id: "task_plan_required",
                    ownerUserId: defaultCurrentUserId,
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
                    ownerUserId: defaultCurrentUserId,
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
                id: "\(defaultCurrentUserId)_\(selfContext.dateKey)",
                coupleId: "cpl_demo",
                subjectUserId: defaultCurrentUserId,
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
                pendingAcknowledgementUserIds: [defaultCurrentUserId],
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
                eligibility: [defaultCurrentUserId: false, "usr_partner": true],
                memberLocalWeekKeys: [defaultCurrentUserId: currentWeekKey, "usr_partner": partnerContext.weekKey],
                updatedAt: now
            )
        ]

        return DemoAppEnvironment(
            userRepository: MemoryUserRepository(seed: users),
            coupleRepository: MemoryCoupleRepository(seed: [couple]),
            deviceInstallationRepository: MemoryDeviceInstallationRepository(seed: []),
            planRepository: MemoryPlanRepository(seed: plans),
            taskRepository: MemoryTaskRepository(seed: tasks),
            settlementRepository: MemorySettlementRepository(seed: settlements),
            rewardWeekRepository: MemoryRewardWeekRepository(seed: rewardWeeks),
            eventRepository: MemoryEventRepository(seed: []),
            sharedSnapshotWriter: SharedSnapshotWriter()
        )
    }
}
