import Foundation
@testable import Kakitori
import SwiftData
import XCTest

@MainActor
final class SessionViewModelTests: SessionViewModelTestCase {
    private func fetchSchedule(for note: Note) throws -> CardSchedule {
        try XCTUnwrap(note.schedule)
    }

    private func fetchDailyStats(for dayKey: String) throws -> DailyStats? {
        var descriptor = FetchDescriptor<DailyStats>(predicate: #Predicate { $0.day == dayKey })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Caught up with no queue but daily target zero

    func testCaughtUpWhenNoQueueAndNoDailyTarget() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42,
            newPerDay: 0, maxReviewsPerDay: 0
        )

        XCTAssertEqual(viewModel.phase, .caughtUp)
        XCTAssertNil(viewModel.currentNote)
        XCTAssertNil(viewModel.summary, "caught-up session must not have a summary")

        let dayKey = clock.adjustedDay(for: scripted.current)
        let stats = try fetchDailyStats(for: dayKey)
        XCTAssertEqual(stats?.secondsStudied ?? 0, 0, "caught-up session must not record study seconds")
    }

    func testCaughtUpWhenDailyTargetMetBeforeSession() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42,
            newPerDay: 1, maxReviewsPerDay: 10
        )

        XCTAssertEqual(viewModel.phase, .prompt)
        XCTAssertNotNil(viewModel.currentNote)
        viewModel.showAnswer()
        scripted.advance(by: 30)
        viewModel.grade(.good)

        XCTAssertEqual(viewModel.phase, .finished)
        let summary1 = try XCTUnwrap(viewModel.summary)
        XCTAssertEqual(summary1.cardsWritten, 1)

        let viewModel2 = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42,
            newPerDay: 1, maxReviewsPerDay: 10
        )

        XCTAssertEqual(viewModel2.phase, .caughtUp, "second session should be caught-up since daily target is met")
        XCTAssertNil(viewModel2.currentNote)
        XCTAssertNil(viewModel2.summary, "caught-up session must not have a summary")
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

    // MARK: - Advancing never leaks the next card's answer

    /// Grading advances the card and starts the answer block's fade-out in the same beat. The block
    /// renders `revealedNote`, so the answer on screen must stay the card just graded until the next
    /// reveal — otherwise the next card's answer is readable through the fade.
    func testRevealedNoteHoldsGradedCardWhileAnswerFadesOut() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let firstNote = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        let secondNote = makeReviewNote(target: "い", dueBefore: baseNow, deck: deck)

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42
        )

        XCTAssertNil(viewModel.revealedNote, "nothing is revealed before the first Show answer")

        viewModel.showAnswer()
        let gradedID = try XCTUnwrap(viewModel.currentNote?.id)
        XCTAssertEqual(viewModel.revealedNote?.id, gradedID)

        viewModel.grade(.good)

        // The card has moved on, but the fading answer block must still show the graded card.
        XCTAssertNotEqual(viewModel.currentNote?.id, gradedID)
        XCTAssertEqual(viewModel.revealedNote?.id, gradedID)

        // Only the next reveal — by which point the block is invisible — swaps the answer.
        let nextID = try XCTUnwrap(viewModel.currentNote?.id)
        viewModel.showAnswer()
        XCTAssertEqual(viewModel.revealedNote?.id, nextID)

        XCTAssertEqual(Set([firstNote.id, secondNote.id]), Set([gradedID, nextID]))
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

    // MARK: - Empty start (daily allowance already exhausted)

    func testEmptyStartRoutsTooCaughtUpState() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42,
            newPerDay: 0, maxReviewsPerDay: 0
        )

        XCTAssertEqual(viewModel.phase, .caughtUp)
        XCTAssertNil(viewModel.currentNote)
        XCTAssertNil(viewModel.summary, "caught-up session must not synthesize a summary")

        let dayKey = clock.adjustedDay(for: scripted.current)
        let stats = try fetchDailyStats(for: dayKey)
        XCTAssertEqual(stats?.secondsStudied ?? 0, 0, "caught-up session must not record study seconds")
    }

    func testEmptyStartShowAnswerAndGradeAreSafeNoOps() {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42,
            newPerDay: 0, maxReviewsPerDay: 0
        )

        XCTAssertEqual(viewModel.phase, .caughtUp)

        viewModel.showAnswer()
        XCTAssertEqual(viewModel.phase, .caughtUp)

        viewModel.grade(.good)
        XCTAssertEqual(viewModel.phase, .caughtUp)
        XCTAssertEqual(viewModel.cardsWritten, 0)
        XCTAssertTrue(viewModel.gradeCounts.isEmpty)
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
