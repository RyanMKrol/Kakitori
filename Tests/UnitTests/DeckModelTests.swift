@testable import Kakitori
import SwiftData
import XCTest

final class DeckModelTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Deck.self, Section.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testDeckScalarFieldsRoundTrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

        let deck = Deck(
            name: "Hiragana",
            jpTitle: "ひらがな",
            sourceDeckName: "Kaki::Hiragana",
            importedAt: fixedDate
        )
        context.insert(deck)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Deck>())
        XCTAssertEqual(fetched.count, 1)
        let refetched = try XCTUnwrap(fetched.first)
        XCTAssertEqual(refetched.name, "Hiragana")
        XCTAssertEqual(refetched.jpTitle, "ひらがな")
        XCTAssertEqual(refetched.sourceDeckName, "Kaki::Hiragana")
        XCTAssertEqual(refetched.importedAt, fixedDate)
        XCTAssertEqual(refetched.id, deck.id)
    }

    func testSectionsRoundTripWithInverseRelationship() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let deck = Deck(
            name: "Hiragana",
            sourceDeckName: "Kaki::Hiragana",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        context.insert(deck)

        let sectionA = Section(name: "Vowels", orderIndex: 0)
        let sectionB = Section(name: "K-row", orderIndex: 1)
        deck.sections.append(sectionA)
        deck.sections.append(sectionB)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Deck>())
        let refetchedDeck = try XCTUnwrap(fetched.first)
        XCTAssertEqual(refetchedDeck.sections.count, 2)
        for section in refetchedDeck.sections {
            XCTAssertEqual(section.deck?.id, refetchedDeck.id)
        }
    }
}
