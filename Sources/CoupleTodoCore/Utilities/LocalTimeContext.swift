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
}
