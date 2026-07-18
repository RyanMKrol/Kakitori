@testable import Kakitori
import SwiftData
import XCTest

/// Integration coverage that the hand-bundled Tofugu decks import in full (the user's requirement:
/// use 100% of each deck). Reads the real `.apkg` out of the app bundle.
final class BundledDeckImportTests: XCTestCase {
    private func appBundle() -> Bundle {
        Bundle(for: DeckLoadModel.self)
    }

    @MainActor
    func testHiraganaImportsAll101() async throws {
        try await assertFullImport(deckNameContains: "Hiragana", expected: 101)
    }

    @MainActor
    func testKatakanaImportsAll124() async throws {
        try await assertFullImport(deckNameContains: "Katakana", expected: 124)
    }

    /// Parses + imports the named bundled deck into an in-memory store and asserts every note both
    /// persists AND is reachable through `deck.sections` — the latter is the count the deck card shows,
    /// and a section-orphaned note (the bug this guards) imports but stays invisible.
    @MainActor
    private func assertFullImport(deckNameContains name: String, expected: Int) async throws {
        let urls = BundledDeckLoader.bundledDeckURLs(in: appBundle())
        let deckURL = try XCTUnwrap(urls.first { $0.lastPathComponent.contains(name) })

        let container = try ModelContainer(
            for: Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let importer = ApkgImporter(container: container, mediaBaseURL: FileManager.default.temporaryDirectory)

        let parsed = try await importer.parse(url: deckURL)
        XCTAssertEqual(parsed.notes.count, expected, "Parsed notes from collection.anki21")

        let ids = Set(parsed.notes.map { NoteIdentity.uuid(forAnkiGUID: $0.ankiGUID) })
        XCTAssertEqual(ids.count, expected, "Distinct note identities (no collisions)")

        let deckID = try await importer.apply(parsed)
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<Note>()).count,
            expected,
            "Persisted Note rows"
        )

        let deck = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<Deck>()).first { $0.id == deckID }
        )
        let sectionVisible = deck.sections.flatMap(\.notes).count(where: { !$0.isDeleted })
        XCTAssertEqual(sectionVisible, expected, "Notes visible via sections (what the deck card counts)")
    }
}
