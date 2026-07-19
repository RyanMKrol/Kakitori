@testable import Kakitori
import SwiftData
import XCTest

/// Integration coverage that the hand-bundled Foundations source `.apkg` splits into three separate
/// first-party decks (Hiragana / Katakana / Kanji), in full and idempotently. Reads the real `.apkg`
/// out of the app bundle.
final class BundledDeckImportTests: XCTestCase {
    private func appBundle() -> Bundle {
        Bundle(for: DeckLoadModel.self)
    }

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func foundationsURL() throws -> URL {
        let urls = BundledDeckLoader.bundledDeckURLs(in: appBundle())
        return try XCTUnwrap(urls.first { $0.lastPathComponent.contains("Foundations") })
    }

    /// Section-visible note count (what the deck card actually counts — a section-orphaned note is
    /// imported but invisible, which this guards against).
    private func visibleCount(_ deck: Deck) -> Int {
        deck.sections.flatMap(\.notes).count(where: { !$0.isDeleted })
    }

    @MainActor
    func testFoundationsSplitsIntoThreeNamedDecks() async throws {
        let container = try inMemoryContainer()
        let importer = ApkgImporter(
            container: container,
            mediaBaseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )

        try await importer.importDeckSplitBySection(from: foundationsURL(), titles: BundledDeckLoader.sectionTitles)

        let decks = try container.mainContext.fetch(FetchDescriptor<Deck>())
        let byName = Dictionary(uniqueKeysWithValues: decks.map { ($0.name, $0) })

        // Three SEPARATE decks, each with a friendly name + JP title.
        XCTAssertEqual(Set(byName.keys), ["Hiragana", "Katakana", "Kanji"], "Three split decks")
        XCTAssertEqual(byName["Hiragana"]?.jpTitle, "ひらがな")
        XCTAssertEqual(byName["Katakana"]?.jpTitle, "カタカナ")
        XCTAssertEqual(byName["Kanji"]?.jpTitle, "漢字")

        // sourceDeckName is the split key (the re-import idempotence key), not the friendly name.
        XCTAssertEqual(byName["Hiragana"]?.sourceDeckName, "Kakitori Foundations::Hiragana")

        // 100% of each section imported AND visible via sections.
        XCTAssertEqual(try visibleCount(XCTUnwrap(byName["Hiragana"])), 104)
        XCTAssertEqual(try visibleCount(XCTUnwrap(byName["Katakana"])), 104)
        XCTAssertEqual(try visibleCount(XCTUnwrap(byName["Kanji"])), 87)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Note>()).count, 295, "Total notes")
    }

    @MainActor
    func testSplitReimportIsIdempotent() async throws {
        let container = try inMemoryContainer()
        let importer = ApkgImporter(
            container: container,
            mediaBaseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )

        try await importer.importDeckSplitBySection(from: foundationsURL(), titles: BundledDeckLoader.sectionTitles)
        try await importer.importDeckSplitBySection(from: foundationsURL(), titles: BundledDeckLoader.sectionTitles)

        // Still exactly 3 decks / 295 notes after a second import — matched by sourceDeckName, no dupes.
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Deck>()).count, 3)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Note>()).count, 295)
    }
}
