@testable import Kakitori
import XCTest

final class AppClockTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )
        return calendar.date(from: components)!
    }

    func testBeforeFourAMIsPreviousDay() {
        let clock = AppClock.fixed(makeDate(year: 2026, month: 7, day: 17, hour: 3, minute: 59), timeZone: tokyo)
        XCTAssertEqual(clock.adjustedDay(for: clock.now()), "2026-07-16")
    }

    func testAtFourAMIsNewDay() {
        let clock = AppClock.fixed(makeDate(year: 2026, month: 7, day: 17, hour: 4, minute: 0), timeZone: tokyo)
        XCTAssertEqual(clock.adjustedDay(for: clock.now()), "2026-07-17")
    }

    func testLateNightStaysOnPriorDay() {
        let clock = AppClock.fixed(makeDate(year: 2026, month: 7, day: 17, hour: 0, minute: 30), timeZone: tokyo)
        XCTAssertEqual(clock.adjustedDay(for: clock.now()), "2026-07-16")
    }

    func testOrdinaryEveningStaysOnSameDay() {
        let clock = AppClock.fixed(makeDate(year: 2026, month: 7, day: 17, hour: 23, minute: 30), timeZone: tokyo)
        XCTAssertEqual(clock.adjustedDay(for: clock.now()), "2026-07-17")
    }

    func testTodayMatchesAdjustedDayForNow() {
        let date = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
        let clock = AppClock.fixed(date, timeZone: tokyo)
        XCTAssertEqual(clock.today, clock.adjustedDay(for: date))
    }
}
