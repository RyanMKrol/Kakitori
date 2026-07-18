import Foundation
@testable import Kakitori
import SwiftData
import XCTest

/// End-to-end coverage for the Trace session flow (T038): a full session that graduates every
/// card and records stats, and a mid-session close that preserves whatever grades were already
/// given without any extra teardown step.
@MainActor
final class SessionFlowTests: XCTestCase {
    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private let baseNow = Date(timeIntervalSince1970: 1_700_000_000) // Not near a 4 AM boundary.

    override func setUp() {
        super.setUp()

        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(
                for: Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self,
                configurations: config
            )
            modelContext = ModelContext(container)
        } catch {
            XCTFail("Failed to set up ModelContainer: \(error)")
        }
    }

    override func tearDown() {
        modelContext = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeClock() -> AppClock {
        let now = baseNow
        return AppClock(now: { now }, timeZone: .current)
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
    private func makeNewNote(target: String, deck: Deck) -> Note {
        let note = Note(target: target, script: .hiragana)
        let schedule = CardSchedule(state: .new)
        note.schedule = schedule
        deck.sections[0].notes.append(note)
        modelContext.insert(note)
        modelContext.insert(schedule)
        return note
    }

    // MARK: - Full session

    func testFullSessionGraduatesAllCardsAndRecordsStats() throws {
        let clock = makeClock()
        let deck = makeDeck()
        let notes = ["あ", "い", "う", "え"].map { makeNewNote(target: $0, deck: deck) }

        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 7
        )

        var gradesGiven = 0
        var safetyCounter = 0
        while viewModel.phase != .finished {
            XCTAssertLessThan(safetyCounter, 50, "session did not reach .finished in a bounded number of steps")
            viewModel.showAnswer()
            viewModel.grade(.good)
            gradesGiven += 1
            safetyCounter += 1
        }

        XCTAssertEqual(viewModel.phase, .finished)

        try modelContext.save()
        let freshContext = ModelContext(container)
        let schedules = try freshContext.fetch(FetchDescriptor<CardSchedule>())
        XCTAssertEqual(schedules.count, notes.count)
        for schedule in schedules {
            XCTAssertNotEqual(schedule.state, .new)
            XCTAssertNotNil(schedule.dueAt)
        }

        let dayKey = clock.adjustedDay(for: baseNow)
        var descriptor = FetchDescriptor<DailyStats>(predicate: #Predicate { $0.day == dayKey })
        descriptor.fetchLimit = 1
        let stats = try XCTUnwrap(try freshContext.fetch(descriptor).first)
        XCTAssertEqual(stats.cardsWritten, gradesGiven)
    }

    // MARK: - Mid-session close preserves grades

    func testMidSessionCloseWithoutExtraTeardownPreservesGrades() throws {
        let clock = makeClock()
        let deck = makeDeck()
        makeNewNote(target: "あ", deck: deck)
        makeNewNote(target: "い", deck: deck)
        makeNewNote(target: "う", deck: deck)
        makeNewNote(target: "え", deck: deck)

        var viewModel: SessionViewModel? = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 7
        )

        let gradedNoteID = try XCTUnwrap(viewModel?.currentNote?.id)
        viewModel?.showAnswer()
        viewModel?.grade(.good)

        // Discard the view model with no extra teardown call — grading must have already
        // persisted, so nothing further is required for the change to stick.
        viewModel = nil

        try modelContext.save()
        let freshContext = ModelContext(container)
        let notes = try freshContext.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(notes.count, 4)
        for note in notes {
            let schedule = try XCTUnwrap(note.schedule)
            if note.id == gradedNoteID {
                XCTAssertNotEqual(schedule.state, .new)
            } else {
                XCTAssertEqual(schedule.state, .new)
            }
        }
    }
}
