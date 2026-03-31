import XCTest
@testable import CoupleTodoCore

final class ConflictResolverTests: XCTestCase {

    private let now = Date()

    private func makeTask(
        id: String = "task_1",
        status: TaskStatus = .pending,
        syncState: SyncState = .synced,
        updatedAt: Date? = nil
    ) -> TodoTask {
        TodoTask(
            id: id,
            ownerUserId: "usr_1",
            dateKey: "2026-03-25",
            localTimezone: "America/New_York",
            title: "Test task",
            notes: nil,
            bucket: .required,
            priority: .p1,
            status: status,
            sortOrder: 1000,
            completedAtServer: nil,
            updatedAt: updatedAt,
            syncState: syncState
        )
    }

    // MARK: - serverWins strategy

    func testServerWins_serverFinalAlwaysWins() {
        let local = makeTask(status: .completed, syncState: .localPending, updatedAt: now.addingTimeInterval(100))
        let server = makeTask(status: .pending, syncState: .serverFinal, updatedAt: now)

        let result = ConflictResolver.resolve(local: local, server: server, strategy: .serverWins)
        XCTAssertEqual(result.status, .pending, "server_final 應該覆蓋 local 不管 timestamp")
        XCTAssertEqual(result.syncState, .serverFinal)
    }

    func testServerWins_newerServerTimestampWins() {
        let local = makeTask(updatedAt: now)
        let server = makeTask(updatedAt: now.addingTimeInterval(5))

        let result = ConflictResolver.resolve(local: local, server: server, strategy: .serverWins)
        XCTAssertEqual(result.updatedAt, server.updatedAt)
    }

    func testServerWins_olderServerLosesToLocal() {
        let local = makeTask(updatedAt: now.addingTimeInterval(10))
        let server = makeTask(updatedAt: now)

        let result = ConflictResolver.resolve(local: local, server: server, strategy: .serverWins)
        XCTAssertEqual(result.updatedAt, local.updatedAt, "server 較舊時 local 應勝出")
    }

    // MARK: - clientWins strategy

    func testClientWins_serverFinalStillWins() {
        let local = makeTask(status: .completed, syncState: .localPending, updatedAt: now)
        let server = makeTask(status: .pending, syncState: .serverFinal, updatedAt: now)

        let result = ConflictResolver.resolve(local: local, server: server, strategy: .clientWins)
        XCTAssertEqual(result.syncState, .serverFinal, "即使 clientWins 策略，server_final 仍不可被覆蓋")
    }

    func testClientWins_localPreferred() {
        let local = makeTask(status: .completed, syncState: .localPending, updatedAt: now)
        let server = makeTask(status: .pending, syncState: .synced, updatedAt: now.addingTimeInterval(10))

        let result = ConflictResolver.resolve(local: local, server: server, strategy: .clientWins)
        XCTAssertEqual(result.status, .completed, "clientWins 時 local 應覆蓋 server")
    }

    // MARK: - latestTimestamp strategy

    func testLatestTimestamp_newerWins() {
        let local = makeTask(updatedAt: now)
        let server = makeTask(updatedAt: now.addingTimeInterval(30))

        let result = ConflictResolver.resolve(local: local, server: server, strategy: .latestTimestamp)
        XCTAssertEqual(result.updatedAt, server.updatedAt)
    }

    // MARK: - Batch resolve

    func testResolveBatch_mergesBothSides() {
        let localOnly = makeTask(id: "local_only", updatedAt: now)
        let serverOnly = makeTask(id: "server_only", updatedAt: now)
        let shared = makeTask(id: "shared", status: .pending, updatedAt: now)
        let sharedServer = makeTask(id: "shared", status: .completed, syncState: .serverFinal, updatedAt: now)

        let result = ConflictResolver.resolveBatch(
            localTasks: [localOnly, shared],
            serverTasks: [serverOnly, sharedServer]
        )

        XCTAssertEqual(result.count, 3, "local-only + server-only + merged shared = 3")
        let sharedResult = result.first(where: { $0.id == "shared" })
        XCTAssertEqual(sharedResult?.status, .completed, "server_final 版本應覆蓋 local")
    }

    // MARK: - Clock skew

    func testClockSkew_withinTolerance() {
        let client = now
        let server = now.addingTimeInterval(120)
        XCTAssertTrue(
            ConflictResolver.isClockSkewAcceptable(clientTime: client, serverTime: server),
            "120 秒差距在 300 秒容忍範圍內"
        )
    }

    func testClockSkew_exceedsTolerance() {
        let client = now
        let server = now.addingTimeInterval(600)
        XCTAssertFalse(
            ConflictResolver.isClockSkewAcceptable(clientTime: client, serverTime: server),
            "600 秒差距超過 300 秒容忍範圍"
        )
    }
}
