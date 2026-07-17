import Foundation

/// App-wide injected time source. All "current time" reads in domain logic go through this
/// type — `AppClock.system` is the only place allowed to construct `Date()` directly.
struct AppClock {
    var now: @Sendable () -> Date
    var timeZone: TimeZone
    var calendar: Calendar

    init(now: @escaping @Sendable () -> Date, timeZone: TimeZone) {
        self.now = now
        self.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    static let system = AppClock(now: { Date() }, timeZone: .current)

    static func fixed(_ date: Date, timeZone: TimeZone = .current) -> AppClock {
        AppClock(now: { date }, timeZone: timeZone)
    }

    /// The SRS "day" rolls over at 4:00 AM local time (docs/03-srs-algorithm.md §7).
    func adjustedDay(for date: Date) -> String {
        let rolledBack = date.addingTimeInterval(-4 * 3600)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        return formatter.string(from: rolledBack)
    }

    var today: String {
        adjustedDay(for: now())
    }
}
