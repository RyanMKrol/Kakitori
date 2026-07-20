@testable import Kakitori
import XCTest

@MainActor
final class DailyAllowanceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let clock = AppClock.fixed(
        Date(timeIntervalSince1970: 1_700_000_000),
        timeZone: TimeZone(identifier: "UTC")!
    )

    private var endOfToday: Date {
        clock.endOfToday(after: now)
    }

    // MARK: - New allowance capped by newIntroducedToday

    func testRemainingNewCountIsZeroWhenDailyCapAlreadyHit() {
        let notes = (0 ..< 3).map { _ in makeNote(state: .new) }
        let allowance = DailyAllowance.forNotes(
            notes,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 10,
            reviewsDoneToday: 0
        )
        XCTAssertEqual(allowance.newCount, 0)
        XCTAssertTrue(allowance.isAllCaughtUp)
    }

    func testNewCountCappedByRemainingAllowance() {
        let notes = (0 ..< 8).map { _ in makeNote(state: .new) }
        let allowance = DailyAllowance.forNotes(
            notes,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 7,
            reviewsDoneToday: 0
        )
        XCTAssertEqual(allowance.newCount, 3)
    }

    // MARK: - Due reviews capped by remaining review allowance

    func testDueReviewsCappedByRemainingReviewAllowance() {
        let notes = (0 ..< 30).map { i in
            makeNote(state: .review, dueAt: now.addingTimeInterval(TimeInterval(-1000 + i)))
        }
        let allowance = DailyAllowance.forNotes(
            notes,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 95
        )
        XCTAssertEqual(allowance.dueCount, 5)
    }

    func testFutureReviewsNotCountedAsDue() {
        let notes = [makeNote(state: .review, dueAt: now.addingTimeInterval(2 * SRSConstants.secondsPerDay))]
        let allowance = DailyAllowance.forNotes(
            notes,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )
        XCTAssertEqual(allowance.dueCount, 0)
    }

    // MARK: - Due learning is uncapped

    func testDueLearningIsUncapped() {
        let notes = (0 ..< 40).map { _ in makeNote(state: .learning, dueAt: now.addingTimeInterval(-10)) }
        let allowance = DailyAllowance.forNotes(
            notes,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 5,
            newIntroducedToday: 10,
            reviewsDoneToday: 5
        )
        XCTAssertEqual(allowance.learnCount, 40)
        XCTAssertEqual(allowance.total, 40)
    }

    func testNotYetDueLearningIsExcluded() {
        let notes = [makeNote(state: .learning, dueAt: now.addingTimeInterval(600))]
        let allowance = DailyAllowance.forNotes(
            notes,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )
        XCTAssertEqual(allowance.learnCount, 0)
    }

    // MARK: - Aggregate across decks

    func testAggregateMatchesSumAcrossDecks() {
        let deckA = makeDeck(states: [.new, .new, .new])
        let deckB = makeDeck(states: [.review], dueAt: now.addingTimeInterval(-10))

        let allowanceA = DailyAllowance.forDeck(
            deckA,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )
        let allowanceB = DailyAllowance.forDeck(
            deckB,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        let aggregate = DailyAllowance.forDecks(
            [deckA, deckB],
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        XCTAssertEqual(aggregate.newCount, allowanceA.newCount + allowanceB.newCount)
        XCTAssertEqual(aggregate.learnCount, allowanceA.learnCount + allowanceB.learnCount)
        XCTAssertEqual(aggregate.dueCount, allowanceA.dueCount + allowanceB.dueCount)
        XCTAssertEqual(aggregate.total, allowanceA.total + allowanceB.total)
    }

    // MARK: - Matches what SessionQueue.build would serve

    func testCountsAgreeWithSessionQueueBuild() {
        let newNotes = (0 ..< 8).map { _ in makeNote(state: .new) }
        let reviewNotes = (0 ..< 6).map { i in
            makeNote(state: .review, dueAt: now.addingTimeInterval(TimeInterval(-100 + i)))
        }
        let notes = newNotes + reviewNotes

        let allowance = DailyAllowance.forNotes(
            notes,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 4,
            newIntroducedToday: 5,
            reviewsDoneToday: 0
        )

        let entries = notes.map { note in
            QueueEntry(id: note.id, snapshot: Self.snapshot(from: note.schedule!))
        }
        let queue = SessionQueue.build(
            cards: entries,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 4,
            newIntroducedToday: 5,
            reviewsDoneToday: 0
        )

        XCTAssertEqual(allowance.newCount, queue.newCount)
        XCTAssertEqual(allowance.dueCount, queue.dueCount)
        XCTAssertEqual(allowance.learnCount, queue.learnCount)
    }

    // MARK: - TodayBannerView reflects the allotment

    func testBannerAllowanceIsZeroWhenDailyCapsAreHit() {
        let deck = makeDeck(states: [.new, .new])
        let stats = DailyStats(
            day: clock.adjustedDay(for: now),
            newIntroduced: 10,
            reviewsDone: 100,
            deckKey: deck.sourceDeckName
        )

        let allowance = TodayBannerView.calculateAllowance(
            decks: [deck],
            dailyStats: [stats],
            now: now,
            clock: clock,
            settings: AppSettings()
        )

        XCTAssertTrue(allowance.isAllCaughtUp)
        XCTAssertEqual(allowance.total, 0)
    }

    func testBannerAllowanceReflectsRemainingAllotment() {
        let deck = makeDeck(states: [.new, .new, .new])

        let allowance = TodayBannerView.calculateAllowance(
            decks: [deck],
            dailyStats: [],
            now: now,
            clock: clock,
            settings: AppSettings()
        )

        XCTAssertEqual(allowance.total, 3)
    }

    // MARK: - DeckCardView reads "all caught up" when only the daily cap is hit

    func testDeckCardAllCaughtUpWhenBacklogRemainsButCapIsHit() {
        let deck = makeDeck(states: [.new, .new, .new])
        let deckCard = DeckCardView(
            deck: deck,
            now: now,
            newIntroducedToday: 10,
            reviewsDoneToday: 0,
            onStudy: { _ in }
        )
        XCTAssertTrue(deckCard.isAllCaughtUp)
    }

    func testDeckCardNotAllCaughtUpWhenAllowanceRemains() {
        let deck = makeDeck(states: [.new, .new, .new])
        let deckCard = DeckCardView(
            deck: deck,
            now: now,
            newIntroducedToday: 8,
            reviewsDoneToday: 0,
            onStudy: { _ in }
        )
        XCTAssertFalse(deckCard.isAllCaughtUp)
    }

    // MARK: - Completed today progress tracking

    func testCompletedTodayReadsZeroWhenNoCardsCompleted() {
        let deck = makeDeck(states: [.new, .new])
        let allowance = DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        let completed = DailyAllowance.completedToday(
            allotment: allowance,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        XCTAssertEqual(completed, 0)
    }

    func testCompletedTodayReflectsNewIntroduced() {
        let deck = makeDeck(states: [.new, .new, .new, .new, .new])
        let allowance = DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        let completed = DailyAllowance.completedToday(
            allotment: allowance,
            newIntroducedToday: 3,
            reviewsDoneToday: 0
        )

        XCTAssertEqual(completed, 3)
    }

    func testCompletedTodayReflectsReviewsDone() {
        let deck = makeDeck(states: [.review, .review, .review], dueAt: now.addingTimeInterval(-10))
        let allowance = DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        let completed = DailyAllowance.completedToday(
            allotment: allowance,
            newIntroducedToday: 0,
            reviewsDoneToday: 2
        )

        XCTAssertEqual(completed, 2)
    }

    func testCompletedTodayIsTheSum() {
        let deck = makeDeck(states: [.new, .new, .review], dueAt: now.addingTimeInterval(-10))
        let allowance = DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        let completed = DailyAllowance.completedToday(
            allotment: allowance,
            newIntroducedToday: 2,
            reviewsDoneToday: 1
        )

        XCTAssertEqual(completed, 3)
    }

    func testCompletedTodayNeverExceedsAllotment() {
        let deck = makeDeck(states: [.new, .new])
        let allowance = DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        let completed = DailyAllowance.completedToday(
            allotment: allowance,
            newIntroducedToday: 100,
            reviewsDoneToday: 100
        )

        XCTAssertEqual(completed, allowance.total)
        XCTAssertEqual(completed, 2)
    }

    func testCompletedTodayClampedWhenCapsAreHit() {
        let reviewNotes = (0 ..< 30).map { i in
            makeNote(state: .review, dueAt: now.addingTimeInterval(TimeInterval(-1000 + i)))
        }

        let allowance = DailyAllowance.forNotes(
            reviewNotes,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 5,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        let completed = DailyAllowance.completedToday(
            allotment: allowance,
            newIntroducedToday: 0,
            reviewsDoneToday: 20
        )

        XCTAssertEqual(completed, allowance.total)
        XCTAssertEqual(completed, 5)
    }

    func testCompletedTodayFreshDayReadsZero() {
        let deck = makeDeck(states: [.new, .new, .new])
        let allowance = DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: endOfToday,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        let completed = DailyAllowance.completedToday(
            allotment: allowance,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        )

        XCTAssertEqual(completed, 0)
        XCTAssertEqual(allowance.total, 3)
    }

    // MARK: - Fixtures

    private func makeNote(state: CardState, dueAt: Date? = nil) -> Note {
        let schedule = CardSchedule(state: state, dueAt: dueAt)
        return Note(target: "あ", script: .hiragana, schedule: schedule)
    }

    private func makeDeck(states: [CardState], dueAt: Date? = nil) -> Deck {
        let deck = Deck(
            name: "Hiragana",
            sourceDeckName: "Kaki::Hiragana",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        let section = Section(name: "Vowels", orderIndex: 0)
        deck.sections.append(section)

        for state in states {
            let noteDueAt = state == .review ? (dueAt ?? now.addingTimeInterval(-10)) : dueAt
            section.notes.append(makeNote(state: state, dueAt: noteDueAt))
        }

        return deck
    }

    private static func snapshot(from schedule: CardSchedule) -> ScheduleSnapshot {
        ScheduleSnapshot(
            state: schedule.state,
            stepIndex: schedule.stepIndex,
            easeFactor: schedule.easeFactor,
            intervalDays: schedule.intervalDays,
            dueAt: schedule.dueAt,
            lapses: schedule.lapses
        )
    }
}
