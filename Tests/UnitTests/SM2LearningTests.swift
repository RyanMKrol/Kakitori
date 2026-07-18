@testable import Kakitori
import XCTest

final class SM2LearningTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func makeRNG() -> SplitMix64 {
        SplitMix64(seed: 1)
    }

    private func apply(_ grade: Grade, to card: ScheduleSnapshot) -> ScheduleSnapshot {
        var rng = makeRNG()
        return SM2Scheduler().apply(grade, to: card, now: now, rng: &rng)
    }

    // MARK: - Learning, step 0

    func testLearningStep0Again() {
        let card = ScheduleSnapshot(
            state: .learning,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let result = apply(.again, to: card)

        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.stepIndex, 0)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(60))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    func testLearningStep0Hard() {
        let card = ScheduleSnapshot(
            state: .learning,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let result = apply(.hard, to: card)

        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.stepIndex, 0)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(60))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    func testLearningStep0Good() {
        let card = ScheduleSnapshot(
            state: .learning,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let result = apply(.good, to: card)

        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.stepIndex, 1)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(600))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    func testLearningStep0Easy() {
        let card = ScheduleSnapshot(
            state: .learning,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let result = apply(.easy, to: card)

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 4)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(345_600))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    // MARK: - Learning, step 1

    func testLearningStep1Again() {
        let card = ScheduleSnapshot(
            state: .learning,
            stepIndex: 1,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let result = apply(.again, to: card)

        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.stepIndex, 0)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(60))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    func testLearningStep1Hard() {
        let card = ScheduleSnapshot(
            state: .learning,
            stepIndex: 1,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let result = apply(.hard, to: card)

        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.stepIndex, 1)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(600))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    func testLearningStep1Good() {
        let card = ScheduleSnapshot(
            state: .learning,
            stepIndex: 1,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let result = apply(.good, to: card)

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.stepIndex, 0)
        XCTAssertEqual(result.intervalDays, 1)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(86400))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    func testLearningStep1Easy() {
        let card = ScheduleSnapshot(
            state: .learning,
            stepIndex: 1,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let result = apply(.easy, to: card)

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 4)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(345_600))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    // MARK: - Relearning, intervalDays = 10, EF 2.3, lapses 1

    private func makeRelearningTenDayCard() -> ScheduleSnapshot {
        ScheduleSnapshot(state: .relearning, stepIndex: 0, easeFactor: 2.3, intervalDays: 10, dueAt: nil, lapses: 1)
    }

    func testRelearningTenDayAgain() {
        let result = apply(.again, to: makeRelearningTenDayCard())

        XCTAssertEqual(result.state, .relearning)
        XCTAssertEqual(result.stepIndex, 0)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(600))
        XCTAssertEqual(result.easeFactor, 2.3)
        XCTAssertEqual(result.lapses, 1)
    }

    func testRelearningTenDayHard() {
        let result = apply(.hard, to: makeRelearningTenDayCard())

        XCTAssertEqual(result.state, .relearning)
        XCTAssertEqual(result.stepIndex, 0)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(600))
        XCTAssertEqual(result.easeFactor, 2.3)
        XCTAssertEqual(result.lapses, 1)
    }

    func testRelearningTenDayGood() {
        let result = apply(.good, to: makeRelearningTenDayCard())

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 5)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(432_000))
        XCTAssertEqual(result.easeFactor, 2.3)
        XCTAssertEqual(result.lapses, 1)
    }

    func testRelearningTenDayEasy() {
        let result = apply(.easy, to: makeRelearningTenDayCard())

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 5)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(432_000))
        XCTAssertEqual(result.easeFactor, 2.3)
        XCTAssertEqual(result.lapses, 1)
    }

    // MARK: - Relearning, intervalDays = 2

    private func makeRelearningTwoDayCard() -> ScheduleSnapshot {
        ScheduleSnapshot(state: .relearning, stepIndex: 0, easeFactor: 2.5, intervalDays: 2, dueAt: nil, lapses: 1)
    }

    func testRelearningTwoDayGood() {
        let result = apply(.good, to: makeRelearningTwoDayCard())

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 1)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(86400))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    func testRelearningTwoDayEasy() {
        let result = apply(.easy, to: makeRelearningTwoDayCard())

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 4)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(345_600))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    // MARK: - New

    private func makeNewCard() -> ScheduleSnapshot {
        ScheduleSnapshot(state: .new, stepIndex: 0, easeFactor: 2.5, intervalDays: 0, dueAt: nil, lapses: 0)
    }

    func testNewGood() {
        let result = apply(.good, to: makeNewCard())

        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.stepIndex, 1)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(600))
        XCTAssertEqual(result.easeFactor, 2.5)
    }

    func testNewEasy() {
        let result = apply(.easy, to: makeNewCard())

        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 4)
        XCTAssertEqual(result.dueAt, now.addingTimeInterval(345_600))
        XCTAssertEqual(result.easeFactor, 2.5)
    }
}
