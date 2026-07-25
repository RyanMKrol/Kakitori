import Foundation
@testable import Kakitori
import SwiftData
import XCTest

/// Shared in-memory fixture for the SessionViewModel test classes. Subclassed rather than copied
/// so the audio tests and the scheduling tests build their decks the same way (and so neither
/// class grows past the type-body-length limit).
@MainActor
class SessionViewModelTestCase: XCTestCase {
    var modelContext: ModelContext!
    var baseNow = Date(timeIntervalSince1970: 1_700_000_000) // Not near a 4 AM boundary.

    /// `@unchecked Sendable`: only ever mutated from the `@MainActor` test method that owns it;
    /// AppClock's `now` closure requires `@Sendable` even though it always runs on the main actor here.
    final class ScriptedClock: @unchecked Sendable {
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

    func makeClock(_ scripted: ScriptedClock) -> AppClock {
        AppClock(now: { scripted.current }, timeZone: .current)
    }

    @discardableResult
    func makeReviewNote(
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

    func makeDeck() -> Deck {
        let deck = Deck(name: "Test Deck", sourceDeckName: "test", importedAt: baseNow)
        let section = Section(name: "Section 1", orderIndex: 0)
        deck.sections = [section]
        modelContext.insert(deck)
        modelContext.insert(section)
        return deck
    }
}
