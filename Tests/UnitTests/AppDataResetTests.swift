import Foundation
@testable import Kakitori
import SwiftData
import XCTest

@MainActor
final class AppDataResetTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testResetAllWipesEveryModelAndForgetsLoadedVersion() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // Seed a full deck graph + a daily-stats row.
        let deck = Deck(name: "Hiragana", sourceDeckName: "Kakitori Foundations::Hiragana", importedAt: Date())
        let section = Section(name: "Hiragana", orderIndex: 0)
        section.deck = deck
        deck.sections.append(section)
        let note = Note(target: "あ", script: .hiragana, deck: deck)
        note.section = section
        section.notes.append(note)
        let schedule = CardSchedule()
        schedule.note = note
        note.schedule = schedule
        context.insert(deck)
        context.insert(section)
        context.insert(note)
        context.insert(schedule)
        context.insert(DailyStats(day: "2026-07-20", cardsWritten: 5, deckKey: "Kakitori Foundations::Hiragana"))
        try context.save()

        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        defaults.set(BundledDeckLoader.bundleVersion, forKey: "loadedBundledDecksVersion")
        XCTAssertTrue(BundledDeckLoader.isUpToDate(defaults: defaults))

        try AppDataReset.resetAll(container: container, defaults: defaults)

        XCTAssertTrue(try context.fetch(FetchDescriptor<Deck>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Section>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Note>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CardSchedule>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyStats>()).isEmpty)
        // The bundle is now "not loaded", so the next load re-imports the decks fresh.
        XCTAssertFalse(BundledDeckLoader.isUpToDate(defaults: defaults))
    }

    func testResetAllOnEmptyStoreIsANoOpThatStillClearsVersion() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        defaults.set(BundledDeckLoader.bundleVersion, forKey: "loadedBundledDecksVersion")

        try AppDataReset.resetAll(container: container, defaults: defaults)

        XCTAssertTrue(try context.fetch(FetchDescriptor<Deck>()).isEmpty)
        XCTAssertFalse(BundledDeckLoader.isUpToDate(defaults: defaults))
    }
}
