@testable import Kakitori
import XCTest

final class SessionQueueReentryTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Helpers

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

    // MARK: - Basic next() and isFinished

    func testNextReturnsEarliestDue() {
        // Queue: A (due t0 − 60), B (due t0 − 30)
        let idA = UUID()
        let idB = UUID()
        let queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
            QueueEntry(id: idB, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-30))),
        ])

        let next = queue.next(now: t0)
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.id, idA)
    }

    func testIsFinishedWhenEmpty() {
        let queue = SessionQueue(entries: [])
        XCTAssertTrue(queue.isFinished)
    }

    func testIsFinishedFalseWhenNotEmpty() {
        let idA = UUID()
        let queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])
        XCTAssertFalse(queue.isFinished)
    }

    // MARK: - markGraded: Again re-queues at +1m

    func testAgainRequeuesSubdayCard() {
        // Start with two learning cards: A (due t0 − 60), B (due t0 − 30)
        let idA = UUID()
        let idB = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
            QueueEntry(id: idB, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-30))),
        ])

        // next() returns A
        let nextBefore = queue.next(now: t0)
        XCTAssertEqual(nextBefore?.id, idA)

        // Grade A to learning step 0 at t0 + 60
        queue.markGraded(
            idA,
            grade: .again,
            newSnapshot: snapshot(state: .learning, stepIndex: 0, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )

        // Queue should have 2 entries: B (front), A (requeued at back)
        XCTAssertEqual(queue.entries.count, 2)
        XCTAssertFalse(queue.isFinished)

        // next() at t0 should return B (only currently-due)
        let nextAfter = queue.next(now: t0)
        XCTAssertEqual(nextAfter?.id, idB)
    }

    // MARK: - Graduation removes from session

    func testGraduationRemovesCard() {
        // Start with A and B; grade B to review (1-day interval)
        let idA = UUID()
        let idB = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
            QueueEntry(id: idB, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-30))),
        ])

        queue.markGraded(
            idB,
            grade: .good,
            newSnapshot: snapshot(state: .review, intervalDays: 1, dueAt: t0.addingTimeInterval(86400)),
            now: t0
        )

        // Only A remains
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(queue.entries.first?.id, idA)

        // B is gone
        let nextEntry = queue.next(now: t0)
        XCTAssertEqual(nextEntry?.id, idA)
    }

    // MARK: - Empty-queue early serve

    func testEarlyServeWhenQueueWouldIdle() {
        // Only A left (due t0 + 60), now is t0 (before due)
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(60))),
        ])

        // next(now: t0) should return A even though it's not yet due
        let next = queue.next(now: t0)
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.id, idA)
    }

    // MARK: - End rule: "Again" keeps the session open; a non-"Again" grade clears the card

    func testAgainKeepsSessionOpenAndNonAgainClearsIt() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])

        XCTAssertFalse(queue.isFinished)

        // "Again" re-queues → the session stays open.
        queue.markGraded(
            idA,
            grade: .again,
            newSnapshot: snapshot(state: .learning, stepIndex: 0, dueAt: t0.addingTimeInterval(60)),
            now: t0
        )
        XCTAssertFalse(queue.isFinished)
        XCTAssertEqual(queue.entries.count, 1)

        // A non-"Again" grade clears the card for the session — even though SM2 keeps it in a
        // learning step — so the queue empties and the session finishes.
        queue.markGraded(
            idA,
            grade: .good,
            newSnapshot: snapshot(state: .learning, stepIndex: 1, dueAt: t0.addingTimeInterval(660)),
            now: t0.addingTimeInterval(60)
        )
        XCTAssertTrue(queue.isFinished)
        XCTAssertNil(queue.next(now: t0.addingTimeInterval(60)))
    }

    // MARK: - Re-entry when due: position matters

    func testReentryPrefersDueCardInQueueOrder() {
        // A is re-queued (due t0 + 60, at back), C is due learning card (at front)
        let idA = UUID()
        let idC = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idC, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-10))),
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(60))),
        ])

        // at t0 + 61, C is due and earlier in queue, so next() returns C
        let nextAtPlus61 = queue.next(now: t0.addingTimeInterval(61))
        XCTAssertEqual(nextAtPlus61?.id, idC)

        // Grade C to review; now A is the only entry and is now due
        queue.markGraded(
            idC,
            grade: .good,
            newSnapshot: snapshot(state: .review, intervalDays: 1, dueAt: t0.addingTimeInterval(86400)),
            now: t0.addingTimeInterval(61)
        )

        // next(now: t0 + 61) returns A (normally due, not early-served)
        let nextAfter = queue.next(now: t0.addingTimeInterval(61))
        XCTAssertEqual(nextAfter?.id, idA)
    }

    // MARK: - Unknown ID in markGraded is no-op

    func testMarkGradedUnknownIdIsNoop() {
        let idA = UUID()
        let idUnknown = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
        ])

        // Grade unknown card (no-op)
        queue.markGraded(
            idUnknown,
            grade: .good,
            newSnapshot: snapshot(state: .review, intervalDays: 1, dueAt: t0.addingTimeInterval(86400)),
            now: t0
        )

        // A still there
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(queue.entries.first?.id, idA)
    }

    // MARK: - Relearning (sub-day) also re-queues

    func testRelearningSetsRequeue() {
        let idA = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(
                id: idA,
                snapshot: snapshot(state: .review, intervalDays: 10, dueAt: t0.addingTimeInterval(-100))
            ),
        ])

        // Grade to relearning
        queue.markGraded(
            idA,
            grade: .again,
            newSnapshot: snapshot(state: .relearning, dueAt: t0.addingTimeInterval(600)),
            now: t0
        )

        // Should re-queue
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(queue.entries.first?.snapshot.state, .relearning)
    }

    // MARK: - New cards stay unaffected

    func testNewCardsIgnoredByMarkGraded() {
        let idA = UUID()
        let idNew = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-60))),
            QueueEntry(id: idNew, snapshot: snapshot(state: .new, dueAt: nil)),
        ])

        // Shouldn't happen in practice, but: grade a new card non-Again — it leaves, no re-queue.
        queue.markGraded(
            idNew,
            grade: .good,
            newSnapshot: snapshot(state: .new, dueAt: nil),
            now: t0
        )

        // Entry removed; a non-Again grade doesn't re-queue.
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(queue.entries.first?.id, idA)
    }

    // MARK: - Chip counts remain consistent

    func testChipCountsReflectLiveEntries() {
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        var queue = SessionQueue(entries: [
            QueueEntry(id: idA, snapshot: snapshot(state: .new, dueAt: nil)),
            QueueEntry(id: idB, snapshot: snapshot(state: .learning, dueAt: t0.addingTimeInterval(-30))),
            QueueEntry(id: idC, snapshot: snapshot(state: .review, dueAt: t0.addingTimeInterval(100))),
        ])

        XCTAssertEqual(queue.newCount, 1)
        XCTAssertEqual(queue.learnCount, 1)
        XCTAssertEqual(queue.dueCount, 1)

        // "Again" on B re-queues it as a learning entry (a non-Again grade would clear it instead).
        queue.markGraded(
            idB,
            grade: .again,
            newSnapshot: snapshot(state: .learning, stepIndex: 1, dueAt: t0.addingTimeInterval(600)),
            now: t0
        )

        // Still 1 new, 1 learning (re-queued B), 1 review
        XCTAssertEqual(queue.newCount, 1)
        XCTAssertEqual(queue.learnCount, 1)
        XCTAssertEqual(queue.dueCount, 1)
    }
}
