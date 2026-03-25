import XCTest
@testable import CoupleTodoCore

final class FirestoreRepositoriesTests: XCTestCase {
    func testUserCoupleAndDeviceRepositoriesRoundTrip() async throws {
        let store = InMemoryFirestoreDocumentStore()
        let userRepository = FirestoreUserRepository(documentStore: store)
        let coupleRepository = FirestoreCoupleRepository(documentStore: store)
        let deviceRepository = FirestoreDeviceInstallationRepository(documentStore: store)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T09:00:00Z"))

        let user = UserProfile(
            id: "usr_1",
            displayName: "W",
            coupleId: "cpl_1",
            currentTimezone: "America/Chicago",
            currentUtcOffsetMinutes: -360,
            lastLocalDateKey: "2026-03-09",
            lastLocalWeekKey: "2026-W11",
            createdAt: now,
            updatedAt: now
        )
        let couple = Couple(
            id: "cpl_1",
            memberIds: ["usr_1", "usr_2"],
            status: .active,
            weekStartsOn: .monday,
            penaltyPolicy: .default,
            reminderConfig: .default,
            inviteCode: "DEMO42",
            createdAt: now,
            updatedAt: now
        )
        let installation = DeviceInstallation(
            id: "dev_1",
            userId: "usr_1",
            timezone: "America/Chicago",
            utcOffsetMinutes: -360,
            lastLocalDateKey: "2026-03-09",
            supportsLiveActivities: true,
            supportsTimeSensitive: true,
            appVersion: "1.0",
            buildNumber: "100",
            updatedAt: now
        )

        try await userRepository.upsertUser(user)
        try await coupleRepository.upsertCouple(couple)
        try await deviceRepository.upsertInstallation(installation)

        let fetchedUser = try await userRepository.fetchUser(userId: "usr_1")
        let fetchedCouple = try await coupleRepository.fetchCouple(coupleId: "cpl_1")
        let foundCouple = try await coupleRepository.findCouple(inviteCode: "demo42")
        let installations = try await deviceRepository.fetchInstallations(userId: "usr_1")

        XCTAssertEqual(fetchedUser, user)
        XCTAssertEqual(fetchedCouple, couple)
        XCTAssertEqual(foundCouple, couple)
        XCTAssertEqual(installations, [installation])
        let storedPaths = await store.storedDocumentPaths()
        XCTAssertEqual(storedPaths, ["couples/cpl_1", "deviceInstallations/dev_1", "users/usr_1"])
    }

    func testPlanAndTaskRepositoriesUseNestedPathsAndCollectionGroupFetches() async throws {
        let store = InMemoryFirestoreDocumentStore()
        let userRepository = FirestoreUserRepository(documentStore: store)
        let planRepository = FirestorePlanRepository(documentStore: store)
        let taskRepository = FirestoreTaskRepository(documentStore: store, userRepository: userRepository)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T10:00:00Z"))

        let user = UserProfile(
            id: "usr_1",
            displayName: "W",
            coupleId: "cpl_1",
            currentTimezone: "America/Chicago",
            currentUtcOffsetMinutes: -360,
            lastLocalDateKey: "2026-03-09",
            lastLocalWeekKey: "2026-W11",
            createdAt: now,
            updatedAt: now
        )
        try await userRepository.upsertUser(user)

        let plan = DailyPlan(
            id: "usr_1_2026-03-10",
            userId: "usr_1",
            coupleId: "cpl_1",
            dateKey: "2026-03-10",
            localTimezone: "America/Chicago",
            submittedAt: now,
            planningMissed: false,
            localUtcOffsetMinutes: -360,
            lastEditedAt: now,
            requiredCount: 1,
            optionalCount: 1
        )
        let requiredTask = TodoTask(
            id: "task_required",
            ownerUserId: "usr_1",
            dateKey: "2026-03-10",
            localTimezone: "America/Chicago",
            title: "Ship repositories",
            notes: nil,
            bucket: .required,
            priority: .p0,
            status: .pending,
            sortOrder: 2000,
            completedAtServer: nil,
            createdAt: now,
            updatedAt: now
        )
        let optionalTask = TodoTask(
            id: "task_optional",
            ownerUserId: "usr_1",
            dateKey: "2026-03-10",
            localTimezone: "America/Chicago",
            title: "Refine docs",
            notes: nil,
            bucket: .optional,
            priority: .p2,
            status: .pending,
            sortOrder: 1000,
            completedAtServer: nil,
            createdAt: now,
            updatedAt: now
        )

        try await planRepository.upsertPlan(plan)
        try await taskRepository.replaceTasks(
            for: "usr_1",
            dateKey: "2026-03-10",
            tasks: [optionalTask, requiredTask]
        )

        let fetchedPlan = try await planRepository.fetchPlan(userId: "usr_1", dateKey: "2026-03-10")
        let fetchedTasks = try await taskRepository.fetchTasks(userId: "usr_1", dateKey: "2026-03-10")

        XCTAssertEqual(fetchedPlan, plan)
        XCTAssertEqual(fetchedTasks.map(\.id), ["task_required", "task_optional"])

        try await taskRepository.deleteTask(
            id: "task_optional",
            ownerUserId: "usr_1",
            dateKey: "2026-03-10"
        )

        let remainingTasks = try await taskRepository.fetchTasks(userId: "usr_1", dateKey: "2026-03-10")
        XCTAssertEqual(remainingTasks.map(\.id), ["task_required"])
        let storedPaths = await store.storedDocumentPaths()
        XCTAssertEqual(
            storedPaths,
            [
                "couples/cpl_1/plans/usr_1_2026-03-10",
                "couples/cpl_1/plans/usr_1_2026-03-10/tasks/task_required",
                "users/usr_1"
            ]
        )
    }

    func testSettlementRepositoryFetchesLatestAndAcknowledges() async throws {
        let store = InMemoryFirestoreDocumentStore()
        let repository = FirestoreSettlementRepository(documentStore: store)
        let older = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T11:00:00Z"))
        let newer = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T12:00:00Z"))

        let earlySettlement = DailySettlement(
            id: "usr_1_2026-03-08",
            coupleId: "cpl_1",
            subjectUserId: "usr_1",
            counterpartyUserId: "usr_2",
            dateKey: "2026-03-08",
            localTimezone: "America/Chicago",
            localWeekKey: "2026-W10",
            state: .finalized,
            computedAt: older,
            graceAppliedUntil: nil,
            subjectResult: SettlementResult(
                requiredTotal: 1,
                requiredCompleted: 1,
                missedRequiredCount: 0,
                outcome: .pass,
                owesAmount: 0
            ),
            pendingAcknowledgementUserIds: ["usr_1", "usr_2"]
        )
        let latestSettlement = DailySettlement(
            id: "usr_1_2026-03-09",
            coupleId: "cpl_1",
            subjectUserId: "usr_1",
            counterpartyUserId: "usr_2",
            dateKey: "2026-03-09",
            localTimezone: "America/Chicago",
            localWeekKey: "2026-W11",
            state: .finalized,
            computedAt: newer,
            graceAppliedUntil: nil,
            subjectResult: SettlementResult(
                requiredTotal: 2,
                requiredCompleted: 1,
                missedRequiredCount: 1,
                outcome: .fail,
                owesAmount: 50
            ),
            pendingAcknowledgementUserIds: ["usr_1", "usr_2"]
        )

        try await repository.upsertSettlement(earlySettlement)
        try await repository.upsertSettlement(latestSettlement)

        let fetchedLatest = try await repository.fetchLatestSettlement(coupleId: "cpl_1", subjectUserId: "usr_1")
        XCTAssertEqual(fetchedLatest?.id, latestSettlement.id)

        try await repository.acknowledgeSettlement(
            coupleId: "cpl_1",
            settlementId: latestSettlement.id,
            userId: "usr_1"
        )

        let acknowledged = try await repository.fetchSettlement(
            coupleId: "cpl_1",
            settlementId: latestSettlement.id
        )
        XCTAssertEqual(acknowledged?.pendingAcknowledgementUserIds, ["usr_2"])
    }

    func testRewardWeekAndEventRepositoriesPersistPerCoupleScope() async throws {
        let store = InMemoryFirestoreDocumentStore()
        let rewardRepository = FirestoreRewardWeekRepository(documentStore: store)
        let eventRepository = FirestoreEventRepository(documentStore: store)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T13:00:00Z"))

        let rewardWeek = RewardWeek(
            id: "cpl_1_2026-W12",
            coupleId: "cpl_1",
            weekKey: "2026-W12",
            effectiveWeekStartDate: "2026-03-16",
            draftedInWeekKey: "2026-W11",
            rewardText: "Weekend brunch",
            status: .draft,
            eligibility: ["usr_1": true, "usr_2": true],
            memberLocalWeekKeys: [:],
            updatedAt: now
        )
        let olderEvent = EventLogEntry(
            id: "evt_1",
            coupleId: "cpl_1",
            type: .taskCreated,
            actorUserId: "usr_1",
            payload: ["dateKey": "2026-03-09"],
            createdAt: now.addingTimeInterval(-60)
        )
        let newerEvent = EventLogEntry(
            id: "evt_2",
            coupleId: "cpl_1",
            type: .planSubmitted,
            actorUserId: "usr_1",
            payload: ["dateKey": "2026-03-10"],
            createdAt: now
        )

        try await rewardRepository.upsertRewardWeek(rewardWeek)
        try await eventRepository.appendEvent(olderEvent)
        try await eventRepository.appendEvent(newerEvent)

        let fetchedRewardWeek = try await rewardRepository.fetchRewardWeek(coupleId: "cpl_1", weekKey: "2026-W12")
        let events = try await eventRepository.fetchEvents(coupleId: "cpl_1", limit: 1)

        XCTAssertEqual(fetchedRewardWeek, rewardWeek)
        XCTAssertEqual(events.map(\.id), ["evt_2"])
    }
}
