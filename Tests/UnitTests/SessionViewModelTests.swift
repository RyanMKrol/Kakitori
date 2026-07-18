import Foundation
@testable import Kakitori
import SwiftData
import XCTest

@MainActor
final class SessionViewModelTests: XCTestCase {
    private var modelContext: ModelContext!
    private var baseNow = Date(timeIntervalSince1970: 1_700_000_000) // Not near a 4 AM boundary.

    /// `@unchecked Sendable`: only ever mutated from the `@MainActor` test method that owns it;
    /// AppClock's `now` closure requires `@Sendable` even though it always runs on the main actor here.
    private final class ScriptedClock: @unchecked Sendable {
        var current: Date
        init(_ date: Date) {
            current = date
        }

        func advance(by seconds: TimeInterval) {
            current = current.addingTimeInterval(seconds)
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

    @discardableResult
    private func makeReviewNote(
        target: String,
        intervalDays: Double = 10,
        easeFactor: Double = 2.5,
        dueBefore now: Date,
        deck: Deck
    ) -> Note {
        let note = Note(target: target, script: .hiragana)
        let schedule = CardSchedule(
            state: .review,
            stepIndex: 0,
            easeFactor: easeFactor,
            intervalDays: intervalDays,
            dueAt: now.addingTimeInterval(-3600),
            lapses: 0
        )
        note.schedule = schedule
        deck.sections[0].notes.append(note)
        modelContext.insert(note)
        modelContext.insert(schedule)
        return note
    }

    private func makeDeck() -> Deck {
        let deck = Deck(name: "Test Deck", sourceDeckName: "test", importedAt: baseNow)
        let section = Section(name: "Section 1", orderIndex: 0)
        deck.sections = [section]
        modelContext.insert(deck)
        modelContext.insert(section)
        return deck
    }

    private func fetchSchedule(for note: Note) throws -> CardSchedule {
        try XCTUnwrap(note.schedule)
    }

    private func fetchDailyStats(for dayKey: String) throws -> DailyStats? {
        var descriptor = FetchDescriptor<DailyStats>(predicate: #Predicate { $0.day == dayKey })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Happy path

    func testHappyPathThreeReviewCards() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let noteA = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        let noteB = makeReviewNote(target: "い", dueBefore: baseNow, deck: deck)
        let noteC = makeReviewNote(target: "う", dueBefore: baseNow, deck: deck)

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42
        )

        let grades: [Grade] = [.good, .good, .easy]
        for grade in grades {
            XCTAssertEqual(viewModel.phase, .prompt)
            viewModel.showAnswer()
            XCTAssertEqual(viewModel.phase, .revealed)
            scripted.advance(by: 30)
            viewModel.grade(grade)
        }

        XCTAssertEqual(viewModel.phase, .finished)
        let summary = try XCTUnwrap(viewModel.summary)
        XCTAssertEqual(summary.cardsWritten, 3)
        XCTAssertEqual(summary.gradeCounts[.good], 2)
        XCTAssertEqual(summary.gradeCounts[.easy], 1)
        XCTAssertEqual(summary.seconds, 90)

        let intervals = try [noteA, noteB, noteC].map { try fetchSchedule(for: $0).intervalDays }
        XCTAssertEqual(intervals.sorted(), [25, 25, 34])

        let dayKey = clock.adjustedDay(for: scripted.current)
        let stats = try XCTUnwrap(fetchDailyStats(for: dayKey))
        XCTAssertEqual(stats.cardsWritten, 3)
        XCTAssertEqual(stats.reviewsDone, 3)
        XCTAssertEqual(stats.secondsStudied, 90)
    }

    // MARK: - Again re-enters before finish

    func testAgainReentersBeforeFinish() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42
        )

        viewModel.showAnswer()
        viewModel.grade(.again)

        XCTAssertNotEqual(viewModel.phase, .finished)
        XCTAssertEqual(viewModel.currentNote?.id, note.id)

        let schedule = try fetchSchedule(for: note)
        XCTAssertEqual(schedule.state, .relearning)
        XCTAssertEqual(schedule.lapses, 1)

        scripted.advance(by: 600)
        viewModel.showAnswer()
        viewModel.grade(.good)

        XCTAssertEqual(viewModel.phase, .finished)
        let updatedSchedule = try fetchSchedule(for: note)
        XCTAssertEqual(updatedSchedule.intervalDays, 5)
        XCTAssertEqual(viewModel.cardsWritten, 2)
        XCTAssertEqual(viewModel.gradeCounts[.again], 1)
        XCTAssertEqual(viewModel.gradeCounts[.good], 1)
    }

    // MARK: - Close preserves partial progress

    func testClosePreservesPartialProgress() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let firstNote = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        let secondNote = makeReviewNote(target: "い", dueBefore: baseNow, deck: deck)
        let secondScheduleBefore = try fetchSchedule(for: secondNote)
        let secondStateBefore = (
            secondScheduleBefore.state,
            secondScheduleBefore.stepIndex,
            secondScheduleBefore.easeFactor,
            secondScheduleBefore.intervalDays,
            secondScheduleBefore.dueAt,
            secondScheduleBefore.lapses
        )

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42
        )

        viewModel.showAnswer()
        scripted.advance(by: 45)
        viewModel.grade(.good)

        scripted.advance(by: 15)
        viewModel.close()

        let firstSchedule = try fetchSchedule(for: firstNote)
        XCTAssertEqual(firstSchedule.state, .review)
        XCTAssertGreaterThan(firstSchedule.intervalDays, 10)

        let secondSchedule = try fetchSchedule(for: secondNote)
        XCTAssertEqual(secondSchedule.state, secondStateBefore.0)
        XCTAssertEqual(secondSchedule.stepIndex, secondStateBefore.1)
        XCTAssertEqual(secondSchedule.easeFactor, secondStateBefore.2)
        XCTAssertEqual(secondSchedule.intervalDays, secondStateBefore.3)
        XCTAssertEqual(secondSchedule.dueAt, secondStateBefore.4)
        XCTAssertEqual(secondSchedule.lapses, secondStateBefore.5)

        let dayKey = clock.adjustedDay(for: scripted.current)
        let stats = try XCTUnwrap(fetchDailyStats(for: dayKey))
        XCTAssertEqual(stats.cardsWritten, 1)
        XCTAssertEqual(stats.secondsStudied, 60)
    }

    // MARK: - Grading before reveal is a no-op

    func testGradeBeforeShowAnswerIsNoOp() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        let before = try fetchSchedule(for: note)
        let beforeState = (
            before.state,
            before.stepIndex,
            before.easeFactor,
            before.intervalDays,
            before.dueAt,
            before.lapses
        )

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42
        )

        XCTAssertEqual(viewModel.phase, .prompt)
        viewModel.grade(.good)

        XCTAssertEqual(viewModel.phase, .prompt)
        XCTAssertEqual(viewModel.cardsWritten, 0)
        XCTAssertTrue(viewModel.gradeCounts.isEmpty)

        let after = try fetchSchedule(for: note)
        XCTAssertEqual(after.state, beforeState.0)
        XCTAssertEqual(after.stepIndex, beforeState.1)
        XCTAssertEqual(after.easeFactor, beforeState.2)
        XCTAssertEqual(after.intervalDays, beforeState.3)
        XCTAssertEqual(after.dueAt, beforeState.4)
        XCTAssertEqual(after.lapses, beforeState.5)
    }
}
