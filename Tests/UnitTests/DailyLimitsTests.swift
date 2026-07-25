@testable import Kakitori
import XCTest

/// What the daily-limit fields accept. The bug these cover: a number above the cap was thrown away
/// rather than clamped, so typing 99 into a field that stopped at 50 snapped the box back to its
/// old value with no explanation — indistinguishable from the field being broken.
final class DailyLimitsTests: XCTestCase {
    func testInRangeValuesArePassedThrough() {
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("20"), 20)
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("50"), 50)
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("99"), 99)
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("109"), 109)
        XCTAssertEqual(DailyLimits.clampMaxReviewsPerDay("250"), 250)
    }

    func testTheCeilingIsNineHundredAndNinetyNine() {
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("999"), 999)
        XCTAssertEqual(DailyLimits.clampMaxReviewsPerDay("999"), 999)
    }

    func testValuesAboveTheCeilingAreClampedNotDropped() {
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("1000"), 999)
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("40000"), 999)
        XCTAssertEqual(DailyLimits.clampMaxReviewsPerDay("5000"), 999)
    }

    func testValuesBelowTheFloorAreClampedUp() {
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("0"), 1)
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("-5"), 1)
        XCTAssertEqual(DailyLimits.clampMaxReviewsPerDay("0"), 1)
    }

    func testWhitespaceIsIgnored() {
        XCTAssertEqual(DailyLimits.clampNewCardsPerDay("  42 "), 42)
    }

    /// Nothing to read means leave the setting alone — an empty field shouldn't invent a number.
    func testUnreadableInputYieldsNil() {
        XCTAssertNil(DailyLimits.clampNewCardsPerDay(""))
        XCTAssertNil(DailyLimits.clampNewCardsPerDay("   "))
        XCTAssertNil(DailyLimits.clampNewCardsPerDay("abc"))
        XCTAssertNil(DailyLimits.clampMaxReviewsPerDay(""))
    }
}
