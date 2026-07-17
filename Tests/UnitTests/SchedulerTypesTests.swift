@testable import Kakitori
import XCTest

final class SchedulerTypesTests: XCTestCase {
    func testLearningStepsSeconds() {
        XCTAssertEqual(SRSConstants.learningStepsSeconds, [60, 600])
    }

    func testGraduatingIntervalDays() {
        XCTAssertEqual(SRSConstants.graduatingIntervalDays, 1)
    }

    func testEasyGraduatingIntervalDays() {
        XCTAssertEqual(SRSConstants.easyGraduatingIntervalDays, 4)
    }

    func testRelearningStepSeconds() {
        XCTAssertEqual(SRSConstants.relearningStepSeconds, 600)
    }

    func testInitialEase() {
        XCTAssertEqual(SRSConstants.initialEase, 2.5)
    }

    func testMinimumEase() {
        XCTAssertEqual(SRSConstants.minimumEase, 1.3)
    }

    func testAgainEaseDelta() {
        XCTAssertEqual(SRSConstants.againEaseDelta, -0.20)
    }

    func testHardEaseDelta() {
        XCTAssertEqual(SRSConstants.hardEaseDelta, -0.15)
    }

    func testEasyEaseDelta() {
        XCTAssertEqual(SRSConstants.easyEaseDelta, 0.15)
    }

    func testHardIntervalMultiplier() {
        XCTAssertEqual(SRSConstants.hardIntervalMultiplier, 1.2)
    }

    func testEasyBonus() {
        XCTAssertEqual(SRSConstants.easyBonus, 1.3)
    }

    func testMaximumIntervalDays() {
        XCTAssertEqual(SRSConstants.maximumIntervalDays, 365)
    }

    func testMinimumReviewIntervalDays() {
        XCTAssertEqual(SRSConstants.minimumReviewIntervalDays, 1)
    }

    func testLapseIntervalMultiplier() {
        XCTAssertEqual(SRSConstants.lapseIntervalMultiplier, 0.5)
    }

    func testFuzzFraction() {
        XCTAssertEqual(SRSConstants.fuzzFraction, 0.05)
    }

    func testFuzzMinimumIntervalDays() {
        XCTAssertEqual(SRSConstants.fuzzMinimumIntervalDays, 3)
    }

    func testDefaultNewPerDay() {
        XCTAssertEqual(SRSConstants.defaultNewPerDay, 10)
    }

    func testDefaultMaxReviewsPerDay() {
        XCTAssertEqual(SRSConstants.defaultMaxReviewsPerDay, 100)
    }

    func testDayRolloverHour() {
        XCTAssertEqual(SRSConstants.dayRolloverHour, 4)
    }

    func testSecondsPerDay() {
        XCTAssertEqual(SRSConstants.secondsPerDay, 86400)
    }

    func testSplitMix64SameSeedProducesIdenticalSequence() {
        var rngA = SplitMix64(seed: 42)
        var rngB = SplitMix64(seed: 42)

        let aValues = [rngA.next(), rngA.next(), rngA.next()]
        let bValues = [rngB.next(), rngB.next(), rngB.next()]

        XCTAssertEqual(aValues, bValues)
    }

    func testSplitMix64DifferentSeedProducesDifferentFirstValue() {
        var rngA = SplitMix64(seed: 42)
        var rngB = SplitMix64(seed: 43)

        XCTAssertNotEqual(rngA.next(), rngB.next())
    }
}
