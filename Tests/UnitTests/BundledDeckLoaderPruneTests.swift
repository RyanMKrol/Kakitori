import Foundation
@testable import Kakitori
import SwiftData
import XCTest

final class BundledDeckLoaderPruneTests: XCTestCase {
    private let foundationsExpected: Set<String> = [
        "Kakitori Foundations::Hiragana",
        "Kakitori Foundations::Katakana",
        "Kakitori Foundations::Kanji",
    ]

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Inserts a deck with one section, one note, and one schedule; returns the note's id so callers
    /// can assert on its fate after pruning.
    @discardableResult
    private func seedDeck(sourceDeckName: String, name: String, context: ModelContext) -> UUID {
        let deck = Deck(name: name, sourceDeckName: sourceDeckName, importedAt: Date())
        context.insert(deck)

        let section = Section(name: name, orderIndex: 0)
        section.deck = deck
        deck.sections.append(section)
        context.insert(section)

        let note = Note(target: "あ", script: .hiragana, deck: deck)
        note.section = section
        section.notes.append(note)
        context.insert(note)

        let schedule = CardSchedule()
        schedule.note = note
        note.schedule = schedule
        context.insert(schedule)

        return note.id
    }

    func testPruneRemovesRetiredDeckAndCascadesToNoteAndSchedule() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let tofuguNoteID = seedDeck(
            sourceDeckName: "Tofugu Hiragana Anki Deck", name: "Hiragana", context: context
        )
        seedDeck(sourceDeckName: "Kakitori Foundations::Hiragana", name: "Hiragana", context: context)
        seedDeck(sourceDeckName: "Kakitori Foundations::Katakana", name: "Katakana", context: context)
        seedDeck(sourceDeckName: "Kakitori Foundations::Kanji", name: "Kanji", context: context)
        try context.save()

        BundledDeckLoader.pruneRetiredDecks(container: container, keeping: foundationsExpected)

        let remainingDecks = try context.fetch(FetchDescriptor<Deck>())
        XCTAssertEqual(Set(remainingDecks.map(\.sourceDeckName)), foundationsExpected)

        let remainingNotes = try context.fetch(FetchDescriptor<Note>())
        XCTAssertFalse(remainingNotes.contains { $0.id == tofuguNoteID })

        // The Tofugu note's schedule must go with it — the 3 surviving Foundations decks each keep
        // their own schedule, so this is 3, never 4 (no orphan left stranded in the store).
        let remainingSchedules = try context.fetch(FetchDescriptor<CardSchedule>())
        XCTAssertEqual(remainingSchedules.count, 3, "pruning a deck must not orphan its CardSchedule rows")
        XCTAssertFalse(remainingSchedules.contains { $0.note?.id == tofuguNoteID })
    }

    func testPruneIsNoOpWhenOnlyExpectedDecksExist() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        seedDeck(sourceDeckName: "Kakitori Foundations::Hiragana", name: "Hiragana", context: context)
        seedDeck(sourceDeckName: "Kakitori Foundations::Katakana", name: "Katakana", context: context)
        seedDeck(sourceDeckName: "Kakitori Foundations::Kanji", name: "Kanji", context: context)
        try context.save()

        BundledDeckLoader.pruneRetiredDecks(container: container, keeping: foundationsExpected)

        let remainingDecks = try context.fetch(FetchDescriptor<Deck>())
        XCTAssertEqual(Set(remainingDecks.map(\.sourceDeckName)), foundationsExpected)

        let remainingSchedules = try context.fetch(FetchDescriptor<CardSchedule>())
        XCTAssertEqual(remainingSchedules.count, 3)
    }

    /// End-to-end: a store left with the two retired Tofugu decks from a pre-Foundations-split
    /// install ends up with exactly the three Foundations decks after `load()` runs.
    func testLoadPrunesRetiredTofuguDecksAfterFoundationsSplit() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        seedDeck(sourceDeckName: "Tofugu Hiragana Anki Deck", name: "Hiragana", context: context)
        seedDeck(sourceDeckName: "Tofugu Katakana Anki Deck", name: "Katakana", context: context)
        try context.save()

        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)

        let error = await BundledDeckLoader.load(
            container: container, defaults: defaults, bundle: Bundle(for: DeckLoadModel.self)
        )
        XCTAssertNil(error)

        let decks = try context.fetch(FetchDescriptor<Deck>())
        XCTAssertEqual(Set(decks.map(\.sourceDeckName)), foundationsExpected)
    }
}
