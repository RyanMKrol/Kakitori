@testable import Kakitori
import XCTest

/// T077 — the session progress bar must count cards the user has got RIGHT (graded anything but
/// "Again") at least once, not raw grade attempts. It must advance when you grade a card correctly —
/// even if that card is still in its learning steps and hasn't fully graduated — and must never
/// advance on "Again". These tests pin `SessionQueue`'s progress accounting: `initialCount` (the
/// fixed denominator) and `completedCount` (distinct non-Again-graded cards, the numerator).
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
            grade: .again,
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
        queue.markGraded(
            idA,
            grade: .again,
            newSnapshot: snapshot(state: .learning, stepIndex: 0, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 0)

        // A second "Again" (still re-queued) still doesn't count.
        queue.markGraded(
            idA,
            grade: .again,
            newSnapshot: snapshot(state: .relearning, stepIndex: 0, dueAt: t0.addingTimeInterval(120)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 0)
    }

    // MARK: - A correct grade counts even when the card is STILL LEARNING (the T077 fix)

    func testNonAgainGradeCountsEvenWhileCardStaysInLearning() {
        // A brand-new card graded "Good" advances to a learning step (not .review) — it has NOT
        // graduated, but the user got it right, so it must count as done.
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .new, dueAt: nil)),
        ])
        queue.markGraded(
            idA,
            grade: .good,
            newSnapshot: snapshot(state: .learning, stepIndex: 0, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 1, "a correct grade counts even before the card graduates")
    }

    func testHardAlsoCountsAsCorrect() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])
        queue.markGraded(
            idA,
            grade: .hard,
            newSnapshot: snapshot(state: .learning, stepIndex: 0, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 1)
    }

    func testGraduatingGradeCountsOnce() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])
        queue.markGraded(
            idA,
            grade: .easy,
            newSnapshot: snapshot(state: .review, intervalDays: 4, dueAt: t0.addingTimeInterval(4 * 86400)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 1)
        XCTAssertTrue(queue.isFinished)
    }

    // MARK: - Distinct: re-grading an already-counted card doesn't double-count

    func testAgainThenCorrectCountsOnceOnTheCorrectGrade() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])
        // Two Agains — no progress.
        for i in 1 ... 2 {
            queue.markGraded(
                idA,
                grade: .again,
                newSnapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(Double(i) * 60)),
                now: t0
            )
            XCTAssertEqual(queue.completedCount, 0, "no progress after Again #\(i)")
        }
        // Now a correct grade — counts once.
        queue.markGraded(
            idA,
            grade: .good,
            newSnapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(600)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 1)

        // Grading the same card correctly AGAIN (next learning step) does not double-count.
        queue.markGraded(
            idA,
            grade: .good,
            newSnapshot: snapshot(state: .review, intervalDays: 1, dueAt: t0.addingTimeInterval(86400)),
            now: t0
        )
        XCTAssertEqual(queue.completedCount, 1, "distinct — the same card counts at most once")
    }

    // MARK: - A first correct pass over the session reaches 100%, never over-runs

    func testGradingEveryCardCorrectlyOnceReachesButDoesNotExceedDenominator() {
        let idA = UUID()
        let idB = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .new, dueAt: nil)),
            QueueEntry(id: idB, snapshot: snapshot(state: .new, dueAt: nil)),
        ])
        XCTAssertEqual(queue.initialCount, 2)

        // Both graded "Good" on their first pass — still learning, but both count.
        queue.markGraded(
            idA,
            grade: .good,
            newSnapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )
        queue.markGraded(
            idB,
            grade: .good,
            newSnapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )

        XCTAssertEqual(queue.completedCount, 2)
        XCTAssertEqual(queue.completedCount, queue.initialCount, "reaches 100% after a correct first pass")
    }
}
