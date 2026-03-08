import XCTest
@testable import CoupleTodoCore

final class TaskSortingServiceTests: XCTestCase {
    func testSortOrdersByBucketThenPriorityThenSortOrder() {
        let tasks = [
            TodoTask(
                id: "3",
                ownerUserId: "u",
                dateKey: "2026-03-09",
                localTimezone: "Asia/Tokyo",
                title: "optional high",
                notes: nil,
                bucket: .optional,
                priority: .p0,
                status: .pending,
                sortOrder: 1,
                completedAtServer: nil
            ),
            TodoTask(
                id: "2",
                ownerUserId: "u",
                dateKey: "2026-03-09",
                localTimezone: "Asia/Tokyo",
                title: "required p1",
                notes: nil,
                bucket: .required,
                priority: .p1,
                status: .pending,
                sortOrder: 2,
                completedAtServer: nil
            ),
            TodoTask(
                id: "1",
                ownerUserId: "u",
                dateKey: "2026-03-09",
                localTimezone: "Asia/Tokyo",
                title: "required p0",
                notes: nil,
                bucket: .required,
                priority: .p0,
                status: .pending,
                sortOrder: 10,
                completedAtServer: nil
            )
        ]

        let sortedIds = TaskSortingService.sort(tasks).map(\.id)

        XCTAssertEqual(sortedIds, ["1", "2", "3"])
    }
}
