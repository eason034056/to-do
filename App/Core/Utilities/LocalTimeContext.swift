import Foundation

struct LocalTimeContext: Hashable {
    let timezoneIdentifier: String
    let utcOffsetMinutes: Int
    let dateKey: String
    let weekKey: String
}

enum LocalTimeContextFactory {
    static func make(from date: Date = Date(), calendar: Calendar = .current, timezone: TimeZone = .current) -> LocalTimeContext {
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
