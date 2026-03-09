import Foundation

public struct LocalTimeContext: Hashable, Sendable {
    public let timezoneIdentifier: String
    public let utcOffsetMinutes: Int
    public let dateKey: String
    public let weekKey: String

    public init(timezoneIdentifier: String, utcOffsetMinutes: Int, dateKey: String, weekKey: String) {
        self.timezoneIdentifier = timezoneIdentifier
        self.utcOffsetMinutes = utcOffsetMinutes
        self.dateKey = dateKey
        self.weekKey = weekKey
    }
}

public enum LocalTimeContextFactory {
    public static func make(
        from date: Date = Date(),
        calendar: Calendar = Calendar(identifier: .iso8601),
        timezone: TimeZone = .current
    ) -> LocalTimeContext {
        var calendar = calendar
        calendar.timeZone = timezone

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.timeZone = timezone
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let isoWeek = calendar.component(.weekOfYear, from: date)
        let yearForWeek = calendar.component(.yearForWeekOfYear, from: date)

        return LocalTimeContext(
            timezoneIdentifier: timezone.identifier,
            utcOffsetMinutes: timezone.secondsFromGMT(for: date) / 60,
            dateKey: dayFormatter.string(from: date),
            weekKey: String(format: "%04d-W%02d", yearForWeek, isoWeek)
        )
    }

    public static func dateKey(
        from date: Date,
        calendar: Calendar = Calendar(identifier: .iso8601),
        timezone: TimeZone = .current
    ) -> String {
        make(from: date, calendar: calendar, timezone: timezone).dateKey
    }

    public static func weekKey(
        from date: Date,
        calendar: Calendar = Calendar(identifier: .iso8601),
        timezone: TimeZone = .current
    ) -> String {
        make(from: date, calendar: calendar, timezone: timezone).weekKey
    }

    public static func nextDateKey(
        from date: Date,
        calendar: Calendar = Calendar(identifier: .iso8601),
        timezone: TimeZone = .current
    ) -> String {
        var calendar = calendar
        calendar.timeZone = timezone
        let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return dateKey(from: nextDate, calendar: calendar, timezone: timezone)
    }

    public static func nextWeekKey(
        from date: Date,
        calendar: Calendar = Calendar(identifier: .iso8601),
        timezone: TimeZone = .current
    ) -> String {
        var calendar = calendar
        calendar.timeZone = timezone
        let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: date) ?? date
        return weekKey(from: nextWeekDate, calendar: calendar, timezone: timezone)
    }

    public static func startOfWeek(
        from date: Date,
        weekStartsOn: WeekStart,
        calendar: Calendar = Calendar(identifier: .iso8601),
        timezone: TimeZone = .current
    ) -> Date {
        var calendar = calendar
        calendar.timeZone = timezone
        calendar.firstWeekday = weekStartsOn == .monday ? 2 : 1

        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let baseDate = calendar.date(from: components) ?? date
        if weekStartsOn == .monday {
            return baseDate
        }
        return calendar.date(byAdding: .day, value: -1, to: baseDate) ?? baseDate
    }
}
