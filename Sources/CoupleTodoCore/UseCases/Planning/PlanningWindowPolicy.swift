import Foundation

public struct LocalClockTime: Hashable, Codable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var isValid: Bool {
        (0..<24).contains(hour) && (0..<60).contains(minute)
    }

    public var displayString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

public struct PlanningWindowPolicy: Hashable, Sendable {
    public let reminderTime: LocalClockTime
    public let cutoffTime: LocalClockTime

    public init(
        reminderTime: LocalClockTime = LocalClockTime(hour: 21, minute: 30),
        cutoffTime: LocalClockTime = LocalClockTime(hour: 23, minute: 0)
    ) {
        self.reminderTime = reminderTime
        self.cutoffTime = cutoffTime
    }

    public static let `default` = PlanningWindowPolicy()

    func validate(submittedAt: Date, timezone: TimeZone) -> PlanningWindowValidationResult {
        guard reminderTime.isValid, cutoffTime.isValid, reminderTimeInMinutes <= cutoffTimeInMinutes else {
            return .invalidPolicy(reminderTime: reminderTime.displayString, cutoffTime: cutoffTime.displayString)
        }

        guard
            let reminderBoundary = boundaryDate(for: reminderTime, on: submittedAt, timezone: timezone),
            let cutoffBoundary = boundaryDate(for: cutoffTime, on: submittedAt, timezone: timezone)
        else {
            return .invalidPolicy(reminderTime: reminderTime.displayString, cutoffTime: cutoffTime.displayString)
        }

        if submittedAt < reminderBoundary {
            return .beforeReminderTime(
                reminderTime: reminderTime.displayString,
                actualLocalTime: Self.preciseLocalTimeString(from: submittedAt, timezone: timezone)
            )
        }

        if submittedAt > cutoffBoundary {
            return .afterCutoffTime(
                cutoffTime: cutoffTime.displayString,
                actualLocalTime: Self.preciseLocalTimeString(from: submittedAt, timezone: timezone)
            )
        }

        return .withinWindow
    }

    private var reminderTimeInMinutes: Int {
        reminderTime.hour * 60 + reminderTime.minute
    }

    private var cutoffTimeInMinutes: Int {
        cutoffTime.hour * 60 + cutoffTime.minute
    }

    private func boundaryDate(for time: LocalClockTime, on date: Date, timezone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timezone

        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        var boundaryComponents = DateComponents()
        boundaryComponents.calendar = calendar
        boundaryComponents.timeZone = timezone
        boundaryComponents.year = dayComponents.year
        boundaryComponents.month = dayComponents.month
        boundaryComponents.day = dayComponents.day
        boundaryComponents.hour = time.hour
        boundaryComponents.minute = time.minute
        boundaryComponents.second = 0

        return calendar.date(from: boundaryComponents)
    }

    private static func preciseLocalTimeString(from date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = timezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

enum PlanningWindowValidationResult: Equatable {
    case withinWindow
    case beforeReminderTime(reminderTime: String, actualLocalTime: String)
    case afterCutoffTime(cutoffTime: String, actualLocalTime: String)
    case invalidPolicy(reminderTime: String, cutoffTime: String)
}
