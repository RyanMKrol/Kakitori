@testable import Kakitori
import XCTest

final class SessionQueueBuildTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Helpers

    private func snapshot(_ state: CardState, dueAt: Date?) -> ScheduleSnapshot {
        ScheduleSnapshot(
            state: state,
            stepIndex: 0,
            easeFactor: SRSConstants.initialEase,
            intervalDays: 0,
            dueAt: dueAt,
            lapses: 0
        )
    }

    private func entry(_ state: CardState, dueAt: Date?) -> QueueEntry {
        QueueEntry(id: UUID(), snapshot: snapshot(state, dueAt: dueAt))
    }

    /// The next 4:00 AM local time far past `now`; concrete builds pass their own.
    private var farFuture: Date {
        now.addingTimeInterval(SRSConstants.secondsPerDay)
    }

    // MARK: - Review cap vs already-done

    func testReviewCapAgainstReviewsDoneToday() {
        // 30 due reviews with ascending dueAt (id-tagged by offset).
        var cards: [QueueEntry] = []
        var expectedEarliestIDs: [UUID] = []
        for i in 0 ..< 30 {
            let e = entry(.review, dueAt: now.addingTimeInterval(TimeInterval(-1000 + i)))
            cards.append(e)
            if i < 5 { expectedEarliestIDs.append(e.id) }
        }
        let queue = SessionQueue.build(
            cards: cards,
            now: now,
            endOfToday: farFuture,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 95
        )
        XCTAssertEqual(queue.entries.count, 5)
        XCTAssertEqual(queue.entries.map(\.id), expectedEarliestIDs)
    }

    func testReviewCapExhausted() {
        let cards = (0 ..< 30).map { i in
            entry(.review, dueAt: now.addingTimeInterval(TimeInterval(-1000 + i)))
        }
        let queue = SessionQueue.build(
            cards: cards,
            now: now,
            endOfToday: farFuture,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 100
        )
        XCTAssertTrue(queue.entries.isEmpty)
    }

    // MARK: - New cap vs already-done

    func testNewCapAgainstNewIntroducedToday() {
        let cards = (0 ..< 12).map { _ in entry(.new, dueAt: nil) }
        let queue = SessionQueue.build(
            cards: cards,
            now: now,
            endOfToday: farFuture,
            newPerDay: 10,
            newIntroducedToday: 4,
            reviewsDoneToday: 0
        )
        XCTAssertEqual(queue.entries.count, 6)
        XCTAssertEqual(queue.entries.map(\.id), cards.prefix(6).map(\.id))
    }

    func testNewCapExhausted() {
        let cards = (0 ..< 12).map { _ in entry(.new, dueAt: nil) }
        let queue = SessionQueue.build(
            cards: cards,
            now: now,
            endOfToday: farFuture,
            newPerDay: 10,
            newIntroducedToday: 10,
            reviewsDoneToday: 0
        )
        XCTAssertTrue(queue.entries.isEmpty)
    }

    // MARK: - Learning ordering

    func testLearningSortedByDueAtAndFirst() {
        let l1 = entry(.learning, dueAt: now.addingTimeInterval(-300))
        let l2 = entry(.learning, dueAt: now.addingTimeInterval(-100))
        let l3 = entry(.relearning, dueAt: now.addingTimeInterval(-200))
        let review = entry(.review, dueAt: now.addingTimeInterval(-50))
        let newCard = entry(.new, dueAt: nil)
        // Shuffled input order.
        let cards = [review, l2, newCard, l3, l1]
        let queue = SessionQueue.build(
            cards: cards,
            now: now,
            endOfToday: farFuture,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )
        // Learning block comes first, sorted by dueAt ascending: l1(-300), l3(-200), l2(-100).
        XCTAssertEqual(Array(queue.entries.prefix(3)).map(\.id), [l1.id, l3.id, l2.id])
        // The review and new follow after the learning block.
        XCTAssertTrue(Set(queue.entries.suffix(2).map(\.id)) == Set([review.id, newCard.id]))
    }

    // MARK: - Interleave patterns

    func testInterleaveFourReviewsTwoNew() {
        let r = (0 ..< 4).map { i in entry(.review, dueAt: now.addingTimeInterval(TimeInterval(-100 + i))) }
        let n = (0 ..< 2).map { _ in entry(.new, dueAt: nil) }
        let queue = SessionQueue.build(
            cards: r + n,
            now: now,
            endOfToday: farFuture,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )
        // Expect R1 N1 R2 R3 N2 R4.
        let expected = [r[0].id, n[0].id, r[1].id, r[2].id, n[1].id, r[3].id]
        XCTAssertEqual(queue.entries.map(\.id), expected)
    }

    func testInterleaveTwoReviewsTwoNew() {
        let r = (0 ..< 2).map { i in entry(.review, dueAt: now.addingTimeInterval(TimeInterval(-100 + i))) }
        let n = (0 ..< 2).map { _ in entry(.new, dueAt: nil) }
        let queue = SessionQueue.build(
            cards: r + n,
            now: now,
            endOfToday: farFuture,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )
        // Expect R1 N1 R2 N2 (review wins ties).
        let expected = [r[0].id, n[0].id, r[1].id, n[1].id]
        XCTAssertEqual(queue.entries.map(\.id), expected)
    }

    // MARK: - 4 AM boundary

    func testDayBoundaryInclusion() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 7
        comps.day = 18
        comps.hour = 4
        comps.minute = 0
        comps.second = 0
        let calendar = Calendar.current
        let endOfToday = try XCTUnwrap(calendar.date(from: comps))

        let included = entry(.review, dueAt: endOfToday.addingTimeInterval(-60)) // 03:59
        let excluded = entry(.review, dueAt: endOfToday.addingTimeInterval(60)) // 04:01
        let learningLate = entry(.learning, dueAt: now.addingTimeInterval(1)) // now + 1s, strictly excluded

        let queue = SessionQueue.build(
            cards: [included, excluded, learningLate],
            now: now,
            endOfToday: endOfToday,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )
        let ids = queue.entries.map(\.id)
        XCTAssertTrue(ids.contains(included.id))
        XCTAssertFalse(ids.contains(excluded.id))
        XCTAssertFalse(ids.contains(learningLate.id))
    }

    // MARK: - Chip counts

    func testChipCounts() {
        let cards = [
            entry(.new, dueAt: nil),
            entry(.new, dueAt: nil),
            entry(.learning, dueAt: now.addingTimeInterval(-10)),
            entry(.relearning, dueAt: now.addingTimeInterval(-20)),
            entry(.review, dueAt: now.addingTimeInterval(-30)),
            entry(.review, dueAt: now.addingTimeInterval(-40)),
            entry(.review, dueAt: now.addingTimeInterval(-50)),
        ]
        let queue = SessionQueue.build(
            cards: cards,
            now: now,
            endOfToday: farFuture,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )
        XCTAssertEqual(queue.newCount, 2)
        XCTAssertEqual(queue.learnCount, 2)
        XCTAssertEqual(queue.dueCount, 3)
    }
}
