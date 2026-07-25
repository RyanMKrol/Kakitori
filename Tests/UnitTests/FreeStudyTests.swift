import Foundation
@testable import Kakitori
import SwiftData
import XCTest

/// T083: Free Study is completely decoupled from the SRS — it serves only previously-seen cards,
/// endlessly and shuffled, and must never write `CardSchedule` or `DailyStats`.
@MainActor
final class FreeStudyTests: XCTestCase {
    private var modelContext: ModelContext!
    private var baseNow = Date(timeIntervalSince1970: 1_700_000_000) // Not near a 4 AM boundary.

    /// `@unchecked Sendable`: only ever mutated from the `@MainActor` test method that owns it;
    /// AppClock's `now` closure requires `@Sendable` even though it always runs on the main actor here.
    private final class ScriptedClock: @unchecked Sendable {
        var current: Date
        init(_ date: Date) {
            current = date
        }
    }

    override func setUp() {
        super.setUp()

        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self,
                configurations: config
            )
            modelContext = ModelContext(container)
        } catch {
            XCTFail("Failed to set up ModelContext: \(error)")
        }
    }

    override func tearDown() {
        modelContext = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeClock(_ scripted: ScriptedClock) -> AppClock {
        AppClock(now: { scripted.current }, timeZone: .current)
    }

    private func makeDeck() -> Deck {
        let deck = Deck(name: "Test Deck", sourceDeckName: "test", importedAt: baseNow)
        let section = Section(name: "Section 1", orderIndex: 0)
        deck.sections = [section]
        modelContext.insert(deck)
        modelContext.insert(section)
        return deck
    }

    @discardableResult
    private func makeNote(
        target: String,
        state: CardState,
        deck: Deck,
        easeFactor: Double = 2.5,
        intervalDays: Double = 10,
        dueAt: Date? = nil,
        stepIndex: Int = 0,
        lapses: Int = 0
    ) -> Note {
        let note = Note(target: target, script: .hiragana)
        let schedule = CardSchedule(
            state: state,
            stepIndex: stepIndex,
            easeFactor: easeFactor,
            intervalDays: intervalDays,
            dueAt: dueAt,
            lapses: lapses
        )
        note.schedule = schedule
        deck.sections[0].notes.append(note)
        modelContext.insert(note)
        modelContext.insert(schedule)
        return note
    }

    private func fetchSchedule(for note: Note) throws -> CardSchedule {
        try XCTUnwrap(note.schedule)
    }

    private func fetchAllDailyStats() throws -> [DailyStats] {
        try modelContext.fetch(FetchDescriptor<DailyStats>())
    }

    // MARK: - FreeStudySource: excludes new, includes seen, endless shuffle

    func testFreeStudySourceExcludesNewIncludesSeenAndIsEndless() {
        var rng = SplitMix64(seed: 7)

        let newEntry = QueueEntry(id: UUID(), snapshot: ScheduleSnapshot(
            state: .new, stepIndex: 0, easeFactor: 2.5, intervalDays: 0, dueAt: nil, lapses: 0
        ))
        let learningEntry = QueueEntry(id: UUID(), snapshot: ScheduleSnapshot(
            state: .learning, stepIndex: 0, easeFactor: 2.5, intervalDays: 0, dueAt: nil, lapses: 0
        ))
        let reviewEntry = QueueEntry(id: UUID(), snapshot: ScheduleSnapshot(
            state: .review, stepIndex: 0, easeFactor: 2.5, intervalDays: 10, dueAt: nil, lapses: 0
        ))
        let relearningEntry = QueueEntry(id: UUID(), snapshot: ScheduleSnapshot(
            state: .relearning, stepIndex: 0, easeFactor: 2.5, intervalDays: 0, dueAt: nil, lapses: 1
        ))

        let seenPoolIDs: Set<UUID> = [learningEntry.id, reviewEntry.id, relearningEntry.id]

        var source = FreeStudySource(
            entries: [newEntry, learningEntry, reviewEntry, relearningEntry],
            rng: &rng
        )
        XCTAssertFalse(source.isEmpty)

        // Pull far more items than the pool size (3) — the endless source must keep returning
        // cards (reshuffle-and-continue), and every id drawn must be from the seen pool only.
        var drawnIDs: [UUID] = []
        for _ in 0 ..< 25 {
            guard let entry = source.next(rng: &rng) else {
                XCTFail("endless source returned nil while the pool was non-empty")
                return
            }
            drawnIDs.append(entry.id)
        }

        XCTAssertEqual(drawnIDs.count, 25)
        XCTAssertTrue(drawnIDs.allSatisfy { seenPoolIDs.contains($0) }, "must never draw the .new card")
        XCTAssertFalse(drawnIDs.contains(newEntry.id))

        // Every id in the seen pool actually appears among the draws (shuffle of the seen pool).
        for id in seenPoolIDs {
            XCTAssertTrue(drawnIDs.contains(id), "seen card \(id) never appeared in the endless sequence")
        }
    }

    func testFreeStudySourceEmptyPoolYieldsNothing() {
        var rng = SplitMix64(seed: 1)
        let newEntry = QueueEntry(id: UUID(), snapshot: ScheduleSnapshot(
            state: .new, stepIndex: 0, easeFactor: 2.5, intervalDays: 0, dueAt: nil, lapses: 0
        ))

        var source = FreeStudySource(entries: [newEntry], rng: &rng)
        XCTAssertTrue(source.isEmpty)
        XCTAssertNil(source.next(rng: &rng))
    }

    // MARK: - SessionViewModel Free Study: no CardSchedule / DailyStats writes

    func testFreeStudyGradingWritesNoCardScheduleAndNoDailyStatsChange() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let seenNote = makeNote(
            target: "あ", state: .review, deck: deck,
            easeFactor: 2.5, intervalDays: 10, dueAt: baseNow.addingTimeInterval(-3600)
        )
        makeNote(target: "い", state: .review, deck: deck, dueAt: baseNow.addingTimeInterval(-3600))
        makeNote(target: "う", state: .new, deck: deck) // must never be served

        let before = try fetchSchedule(for: seenNote)
        let beforeState = before.state
        let beforeEase = before.easeFactor
        let beforeInterval = before.intervalDays
        let beforeDueAt = before.dueAt
        let beforeStepIndex = before.stepIndex
        let beforeLapses = before.lapses

        let viewModel = SessionViewModel(
            freeStudyDeck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42
        )

        XCTAssertEqual(viewModel.phase, .prompt)
        XCTAssertNotNil(viewModel.currentNote)
        XCTAssertEqual(viewModel.sessionCardCount, 0, "Free Study must not consume the daily target")
        XCTAssertEqual(viewModel.completedCount, 0)

        // Advance through several cards via the pure grade() no-op.
        for _ in 0 ..< 5 {
            viewModel.showAnswer()
            viewModel.grade(.good)
        }

        XCTAssertNotEqual(viewModel.phase, .finished, "Free Study is endless and never auto-finishes")
        XCTAssertEqual(viewModel.cardsWritten, 5, "cardsWritten tracks in-memory display only")
        XCTAssertEqual(viewModel.gradeCounts, [:], "grade() must not record a grade in Free Study")

        let after = try fetchSchedule(for: seenNote)
        XCTAssertEqual(after.state, beforeState)
        XCTAssertEqual(after.easeFactor, beforeEase)
        XCTAssertEqual(after.intervalDays, beforeInterval)
        XCTAssertEqual(after.dueAt, beforeDueAt)
        XCTAssertEqual(after.stepIndex, beforeStepIndex)
        XCTAssertEqual(after.lapses, beforeLapses)

        let allStats = try fetchAllDailyStats()
        XCTAssertTrue(allStats.isEmpty, "Free Study must never create a DailyStats row")

        XCTAssertEqual(viewModel.sessionCardCount, 0)
        XCTAssertEqual(viewModel.completedCount, 0)
    }

    func testFreeStudyCloseDoesNotRecordStudySeconds() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        makeNote(target: "あ", state: .review, deck: deck, dueAt: baseNow.addingTimeInterval(-3600))

        let viewModel = SessionViewModel(
            freeStudyDeck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 1
        )
        viewModel.close()

        let allStats = try fetchAllDailyStats()
        XCTAssertTrue(allStats.isEmpty, "Free Study close() must not write DailyStats")
    }

    func testFreeStudyEmptySeenPoolYieldsNoCard() {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        makeNote(target: "あ", state: .new, deck: deck) // only a new card — no seen pool

        let viewModel = SessionViewModel(
            freeStudyDeck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 3
        )

        XCTAssertEqual(viewModel.phase, .caughtUp)
        XCTAssertNil(viewModel.currentNote)
    }

    // MARK: - Normal SRS grade path is unchanged

    func testNormalGradePathStillWritesCardSchedule() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        let note = makeNote(target: "あ", state: .review, deck: deck, dueAt: baseNow.addingTimeInterval(-3600))

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42
        )

        viewModel.showAnswer()
        viewModel.grade(.good)

        let schedule = try fetchSchedule(for: note)
        XCTAssertNotEqual(schedule.intervalDays, 10, "normal SRS grade path must still update the schedule")

        let allStats = try fetchAllDailyStats()
        XCTAssertFalse(allStats.isEmpty, "normal SRS grade path must still write DailyStats")
    }
}
