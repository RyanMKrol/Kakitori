@testable import Kakitori
import XCTest

final class SM2PreviewTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000_000)

    func testPreviewReturnsAllFourGrades() {
        let snapshot = ScheduleSnapshot(
            state: .new,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let scheduler = SM2Scheduler()
        let previews = scheduler.preview(for: snapshot, now: now)

        XCTAssertEqual(previews.count, 4)
        XCTAssert(previews[.again] != nil)
        XCTAssert(previews[.hard] != nil)
        XCTAssert(previews[.good] != nil)
        XCTAssert(previews[.easy] != nil)
    }

    func testPreviewBypassesFuzz() {
        let snapshot = ScheduleSnapshot(
            state: .review,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 10,
            dueAt: now,
            lapses: 0
        )
        let fuzzEnabledScheduler = SM2Scheduler(fuzzEnabled: true)
        let fuzzDisabledScheduler = SM2Scheduler(fuzzEnabled: false)

        let fuzzyPreviews = fuzzEnabledScheduler.preview(for: snapshot, now: now)
        var rng = SplitMix64(seed: 0)
        let nonfuzzyApply = fuzzDisabledScheduler.apply(.good, to: snapshot, now: now, rng: &rng)

        let goodPreview = fuzzyPreviews[.good]
        XCTAssertNotNil(goodPreview)
        XCTAssertEqual(goodPreview?.dueAt, nonfuzzyApply.dueAt)
        XCTAssertEqual(goodPreview?.intervalDays, nonfuzzyApply.intervalDays)
    }

    func testPreviewNewCardLearning() {
        let snapshot = ScheduleSnapshot(
            state: .new,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let scheduler = SM2Scheduler()
        let previews = scheduler.preview(for: snapshot, now: now)

        XCTAssertEqual(previews[.again]?.label, "<1m")
        XCTAssertEqual(previews[.hard]?.label, "<1m")
        XCTAssertEqual(previews[.good]?.label, "10m")
        XCTAssertEqual(previews[.easy]?.label, "4d")
    }

    func testPreviewLearningStep0() {
        let snapshot = ScheduleSnapshot(
            state: .learning,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: now,
            lapses: 0
        )
        let scheduler = SM2Scheduler()
        let previews = scheduler.preview(for: snapshot, now: now)

        XCTAssertEqual(previews[.again]?.label, "<1m")
        XCTAssertEqual(previews[.hard]?.label, "<1m")
        XCTAssertEqual(previews[.good]?.label, "10m")
        XCTAssertEqual(previews[.easy]?.label, "4d")
    }

    func testPreviewLearningStep1() {
        let snapshot = ScheduleSnapshot(
            state: .learning,
            stepIndex: 1,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: now,
            lapses: 0
        )
        let scheduler = SM2Scheduler()
        let previews = scheduler.preview(for: snapshot, now: now)

        XCTAssertEqual(previews[.good]?.label, "1d")
    }

    func testPreviewReviewI10() {
        let snapshot = ScheduleSnapshot(
            state: .review,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 10,
            dueAt: now,
            lapses: 0
        )
        let scheduler = SM2Scheduler()
        let previews = scheduler.preview(for: snapshot, now: now)

        XCTAssertEqual(previews[.again]?.label, "10m")
        XCTAssertEqual(previews[.hard]?.label, "12d")
        XCTAssertEqual(previews[.good]?.label, "25d")
        XCTAssertEqual(previews[.easy]?.label, "34d")
    }

    func testPreviewRelearningI10Good() {
        let snapshot = ScheduleSnapshot(
            state: .relearning,
            stepIndex: 0,
            easeFactor: 2.3,
            intervalDays: 10,
            dueAt: now,
            lapses: 1
        )
        let scheduler = SM2Scheduler()
        let previews = scheduler.preview(for: snapshot, now: now)

        XCTAssertEqual(previews[.good]?.label, "5d")
    }

    func testPreviewEqualsApplyForAllGradesNewCard() {
        let snapshot = ScheduleSnapshot(
            state: .new,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: nil,
            lapses: 0
        )
        let scheduler = SM2Scheduler(fuzzEnabled: true)
        let previews = scheduler.preview(for: snapshot, now: now)

        for grade in Grade.allCases {
            var rng = SplitMix64(seed: 0)
            let applied = SM2Scheduler(fuzzEnabled: false).apply(grade, to: snapshot, now: now, rng: &rng)

            XCTAssertEqual(previews[grade]?.dueAt, applied.dueAt ?? now, "grade \(grade)")
            XCTAssertEqual(previews[grade]?.intervalDays, applied.intervalDays, "grade \(grade)")
        }
    }

    func testPreviewEqualsApplyForAllGradesLearningStep0() {
        let snapshot = ScheduleSnapshot(
            state: .learning,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: now,
            lapses: 0
        )
        let scheduler = SM2Scheduler(fuzzEnabled: true)
        let previews = scheduler.preview(for: snapshot, now: now)

        for grade in Grade.allCases {
            var rng = SplitMix64(seed: 0)
            let applied = SM2Scheduler(fuzzEnabled: false).apply(grade, to: snapshot, now: now, rng: &rng)

            XCTAssertEqual(previews[grade]?.dueAt, applied.dueAt ?? now, "grade \(grade)")
            XCTAssertEqual(previews[grade]?.intervalDays, applied.intervalDays, "grade \(grade)")
        }
    }

    func testPreviewEqualsApplyForAllGradesLearningStep1() {
        let snapshot = ScheduleSnapshot(
            state: .learning,
            stepIndex: 1,
            easeFactor: 2.5,
            intervalDays: 0,
            dueAt: now,
            lapses: 0
        )
        let scheduler = SM2Scheduler(fuzzEnabled: true)
        let previews = scheduler.preview(for: snapshot, now: now)

        for grade in Grade.allCases {
            var rng = SplitMix64(seed: 0)
            let applied = SM2Scheduler(fuzzEnabled: false).apply(grade, to: snapshot, now: now, rng: &rng)

            XCTAssertEqual(previews[grade]?.dueAt, applied.dueAt ?? now, "grade \(grade)")
            XCTAssertEqual(previews[grade]?.intervalDays, applied.intervalDays, "grade \(grade)")
        }
    }

    func testPreviewEqualsApplyForAllGradesReview() {
        let snapshot = ScheduleSnapshot(
            state: .review,
            stepIndex: 0,
            easeFactor: 2.5,
            intervalDays: 10,
            dueAt: now,
            lapses: 0
        )
        let scheduler = SM2Scheduler(fuzzEnabled: true)
        let previews = scheduler.preview(for: snapshot, now: now)

        for grade in Grade.allCases {
            var rng = SplitMix64(seed: 0)
            let applied = SM2Scheduler(fuzzEnabled: false).apply(grade, to: snapshot, now: now, rng: &rng)

            XCTAssertEqual(previews[grade]?.dueAt, applied.dueAt ?? now, "grade \(grade)")
            XCTAssertEqual(previews[grade]?.intervalDays, applied.intervalDays, "grade \(grade)")
        }
    }

    func testPreviewEqualsApplyForAllGradesRelearning() {
        let snapshot = ScheduleSnapshot(
            state: .relearning,
            stepIndex: 0,
            easeFactor: 2.3,
            intervalDays: 10,
            dueAt: now,
            lapses: 1
        )
        let scheduler = SM2Scheduler(fuzzEnabled: true)
        let previews = scheduler.preview(for: snapshot, now: now)

        for grade in Grade.allCases {
            var rng = SplitMix64(seed: 0)
            let applied = SM2Scheduler(fuzzEnabled: false).apply(grade, to: snapshot, now: now, rng: &rng)

            XCTAssertEqual(previews[grade]?.dueAt, applied.dueAt ?? now, "grade \(grade)")
            XCTAssertEqual(previews[grade]?.intervalDays, applied.intervalDays, "grade \(grade)")
        }
    }
}
