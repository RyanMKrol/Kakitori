@testable import Kakitori
import XCTest

/// T077 — the session progress bar must count cards COMPLETED (graduated out of learning), not
/// grade attempts, so it never advances on "Again". These tests pin `SessionQueue`'s progress
/// accounting: `initialCount` (the fixed denominator) and `completedCount` (the monotonic numerator).
final class SessionQueueProgressTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func snapshot(
        state: CardState,
        stepIndex: Int = 0,
        intervalDays: Double = 0,
        dueAt: Date?
    ) -> ScheduleSnapshot {
        ScheduleSnapshot(
            state: state,
            stepIndex: stepIndex,
            easeFactor: SRSConstants.initialEase,
            intervalDays: intervalDays,
            dueAt: dueAt,
            lapses: 0
        )
    }

    // MARK: - Fixed denominator

    func testInitialCountIsDistinctCardsAtBuildAndCompletedStartsAtZero() {
        let queue = SessionQueue(entries: [
            QueueEntry(id: UUID(), snapshot: snapshot(state: .new, dueAt: nil)),
            QueueEntry(id: UUID(), snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-30))),
            QueueEntry(id: UUID(), snapshot: snapshot(state: .review, dueAt: t0.addingTimeInterval(-10))),
        ])
        XCTAssertEqual(queue.initialCount, 3)
        XCTAssertEqual(queue.completedCount, 0)
    }

    func testDenominatorDoesNotGrowWhenCardIsRequeued() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])
        // "Again" re-queues the card; the fixed denominator must stay 1, not grow with the queue.
        queue.markGraded(
            idA,
            newSnapshot: snapshot(state: .learning, stepIndex: 0, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )
        XCTAssertEqual(queue.initialCount, 1)
    }

    // MARK: - "Again" must NOT count as a completion

    func testAgainDoesNotIncrementCompletedCount() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])
        // Graded "Again" → stays in learning (re-queued). Not a completion.
        queue.markGraded(
            idA,
            newSnapshot: snapshot(state: .learning, stepIndex: 0, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 0)

        // Relearning (a lapsed review re-entering) is likewise NOT a completion.
        queue.markGraded(
            idA,
            newSnapshot: snapshot(state: .relearning, stepIndex: 0, dueAt: t0.addingTimeInterval(120)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 0)
    }

    // MARK: - Graduation counts exactly once

    func testGraduatingGradeIncrementsCompletedCountOnce() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])
        queue.markGraded(
            idA,
            newSnapshot: snapshot(state: .review, intervalDays: 1, dueAt: t0.addingTimeInterval(86400)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 1)
        XCTAssertTrue(queue.isFinished)
    }

    func testGradedReviewCardCountsAsCompleted() {
        // A card entering the session already in .review, graded and leaving, counts once.
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .review, dueAt: t0.addingTimeInterval(-10))),
        ])
        queue.markGraded(
            idA,
            newSnapshot: snapshot(state: .review, intervalDays: 4, dueAt: t0.addingTimeInterval(4 * 86400)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 1)
    }

    // MARK: - "Again" repeatedly, then graduate → completed exactly once

    func testMultipleAgainsThenGraduateCountsOnce() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])
        // Three "Again"s — still learning each time, never completed.
        for i in 1 ... 3 {
            queue.markGraded(
                idA,
                newSnapshot: snapshot(state: .learning, stepIndex: 0, dueAt: t0.addingTimeInterval(Double(i) * 60)),
                now: t0
            )
            XCTAssertEqual(queue.completedCount, 0, "still learning after Again #\(i)")
        }
        // Finally graduates.
        queue.markGraded(
            idA,
            newSnapshot: snapshot(state: .review, intervalDays: 1, dueAt: t0.addingTimeInterval(86400)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 1, "completed exactly once across all those attempts")
    }

    // MARK: - Whole session reaches denominator, never over-runs

    func testCompletingEverySessionCardReachesButDoesNotExceedDenominator() {
        let idA = UUID()
        let idB = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
            QueueEntry(id: idB, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-30))),
        ])
        XCTAssertEqual(queue.initialCount, 2)

        // A: one Again, then graduate. B: graduate straight away.
        queue.markGraded(idA, newSnapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(60)), now: t0)
        queue.markGraded(
            idA,
            newSnapshot: snapshot(state: .review, intervalDays: 1, dueAt: t0.addingTimeInterval(86400)),
            now: t0
        )
        queue.markGraded(
            idB,
            newSnapshot: snapshot(state: .review, intervalDays: 1, dueAt: t0.addingTimeInterval(86400)),
            now: t0
        )

        // completed == denominator (100%), and never over-runs it.
        XCTAssertEqual(queue.completedCount, 2)
        XCTAssertEqual(queue.completedCount, queue.initialCount)
        XCTAssertTrue(queue.isFinished)
    }
}
