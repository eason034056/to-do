import XCTest
@testable import CoupleTodoCore

final class LocalTimeContextFactoryTests: XCTestCase {
    func testMakeUsesProvidedTimezoneForDateKeyAndOffset() throws {
        let utcDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T23:30:00Z"))
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))

        let context = LocalTimeContextFactory.make(from: utcDate, timezone: tokyo)

        XCTAssertEqual(context.timezoneIdentifier, "Asia/Tokyo")
        XCTAssertEqual(context.dateKey, "2026-03-09")
        XCTAssertEqual(context.utcOffsetMinutes, 540)
    }

    func testMakeBuildsISOWeekKey() throws {
        let utcDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z"))
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))

        let context = LocalTimeContextFactory.make(from: utcDate, timezone: utc)

        XCTAssertEqual(context.weekKey, "2026-W01")
    }
}
