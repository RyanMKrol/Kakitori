@testable import Kakitori
import XCTest

final class SM2ReviewTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func apply(
        _ grade: Grade,
        to card: ScheduleSnapshot,
        fuzzEnabled: Bool = false,
        seed: UInt64 = 1
    ) -> ScheduleSnapshot {
        var rng = SplitMix64(seed: seed)
        let scheduler = SM2Scheduler(fuzzEnabled: fuzzEnabled)
        return scheduler.apply(grade, to: card, now: now, rng: &rng)
    }

    private func makeReviewCard(
        intervalDays: Double = 10,
        easeFactor: Double = 2.5,
        lapses: Int = 0
    ) -> ScheduleSnapshot {
        ScheduleSnapshot(
            state: .review,
            stepIndex: 0,
            easeFactor: easeFactor,
            intervalDays: intervalDays,
            dueAt: nil,
            lapses: lapses
        )
    }

    // MARK: - Basic review transitions (fuzz disabled)

    func testReviewAgain() {
        let card = makeReviewCard(intervalDays: 10, easeFactor: 2.5, lapses: 0)
        let result = apply(.again, to: card, fuzzEnabled: false)

        XCTAssertEqual(result.state, .relearning)
        XCTAssertEqual(result.lapses, 1)
        XCTAssertEqual(result.easeFactor, 2.3)
        XCTAssertEqual(result.intervalDays, 10)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(600))
    }

    func testReviewHard() {
        let card = makeReviewCard(intervalDays: 10, easeFactor: 2.5, lapses: 0)
        let result = apply(.hard, to: card, fuzzEnabled: false)

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.easeFactor, 2.35)
        XCTAssertEqual(result.intervalDays, 12)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(1_036_800))
        XCTAssertEqual(result.lapses, 0)
    }

    func testReviewGood() {
        let card = makeReviewCard(intervalDays: 10, easeFactor: 2.5, lapses: 0)
        let result = apply(.good, to: card, fuzzEnabled: false)

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.easeFactor, 2.5)
        XCTAssertEqual(result.intervalDays, 25)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(2_160_000))
        XCTAssertEqual(result.lapses, 0)
    }

    func testReviewEasy() {
        let card = makeReviewCard(intervalDays: 10, easeFactor: 2.5, lapses: 0)
        let result = apply(.easy, to: card, fuzzEnabled: false)

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.easeFactor, 2.65)
        XCTAssertEqual(result.intervalDays, 34)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(2_937_600))
        XCTAssertEqual(result.lapses, 0)
    }

    // MARK: - Ease floor

    func testEaseFloorAgain() {
        let card = makeReviewCard(intervalDays: 10, easeFactor: 1.4, lapses: 0)
        let result = apply(.again, to: card, fuzzEnabled: false)

        XCTAssertEqual(result.easeFactor, 1.3)
    }

    func testEaseFloorHard() {
        let card = makeReviewCard(intervalDays: 10, easeFactor: 1.35, lapses: 0)
        let result = apply(.hard, to: card, fuzzEnabled: false)

        XCTAssertEqual(result.easeFactor, 1.3)
    }

    func testEaseFloorHardAtMinimum() {
        let card = makeReviewCard(intervalDays: 10, easeFactor: 1.3, lapses: 0)
        let result = apply(.hard, to: card, fuzzEnabled: false)

        XCTAssertEqual(result.easeFactor, 1.3)
    }

    // MARK: - Interval clamping

    func testIntervalClampMax() {
        let card = makeReviewCard(intervalDays: 300, easeFactor: 2.5, lapses: 0)
        let result = apply(.good, to: card, fuzzEnabled: false)

        XCTAssertEqual(result.intervalDays, 365)
    }

    // MARK: - Fuzz property tests

    func testFuzzBoundsPropertyTest() {
        let card = makeReviewCard(intervalDays: 10, easeFactor: 2.5, lapses: 0)
        let lowerBound = now.addingTimeInterval(2_160_000 * 0.95)
        let upperBound = now.addingTimeInterval(2_160_000 * 1.05)

        var distinctDueAts = Set<Date>()

        for seed in 0 ..< 100 {
            let result = apply(.good, to: card, fuzzEnabled: true, seed: UInt64(seed))

            XCTAssertEqual(result.intervalDays, 25, "Interval should always be 25")
            XCTAssertGreaterThanOrEqual(
                result.dueAt ?? .distantPast,
                lowerBound,
                "DueAt should be within lower bound for seed \(seed)"
            )
            XCTAssertLessThanOrEqual(
                result.dueAt ?? .distantFuture,
                upperBound,
                "DueAt should be within upper bound for seed \(seed)"
            )

            if let dueAt = result.dueAt {
                distinctDueAts.insert(dueAt)
            }
        }

        XCTAssertGreaterThanOrEqual(distinctDueAts.count, 2, "Should have at least 2 distinct dueAt values")
    }

    func testNoFuzzBelowThreshold() {
        let card = makeReviewCard(intervalDays: 2, easeFactor: 2.5, lapses: 0)
        let exactDueAt = now.addingTimeInterval(172_800)

        for seed in 0 ..< 100 {
            let result = apply(.hard, to: card, fuzzEnabled: true, seed: UInt64(seed))

            XCTAssertEqual(result.intervalDays, 2)
            XCTAssertEqual(result.dueAt, exactDueAt)
        }
    }
}
