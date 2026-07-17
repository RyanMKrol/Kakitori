@testable import Kakitori
import SwiftData
import XCTest

final class NoteModelTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Deck.self, Section.self, Note.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testNoteScalarFieldsRoundTrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let note = Note(
            target: "ありがとう",
            pronunciation: "arigatou",
            english: "thank you",
            script: .hiragana,
            units: ["あ", "り", "が", "と", "う"]
        )
        context.insert(note)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(fetched.count, 1)
        let refetched = try XCTUnwrap(fetched.first)
        XCTAssertEqual(refetched.target, "ありがとう")
        XCTAssertEqual(refetched.pronunciation, "arigatou")
        XCTAssertEqual(refetched.english, "thank you")
        XCTAssertEqual(refetched.script, .hiragana)
        XCTAssertEqual(refetched.units, ["あ", "り", "が", "と", "う"])
        XCTAssertEqual(refetched.isDeleted, false)
    }

    func testNoteAppendedToSectionRoundTripsRelationship() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let section = Section(name: "Vowels", orderIndex: 0)
        context.insert(section)

        let note = Note(target: "あ", script: .hiragana, units: ["あ"])
        section.notes.append(note)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Section>())
        let refetchedSection = try XCTUnwrap(fetched.first)
        XCTAssertEqual(refetchedSection.notes.count, 1)
        let refetchedNote = try XCTUnwrap(refetchedSection.notes.first)
        XCTAssertTrue(refetchedNote.section === refetchedSection)
    }

    func testScriptRawValueMapping() {
        XCTAssertEqual(Script(rawValue: "kanji"), .kanji)
        XCTAssertEqual(Script.mixed.rawValue, "mixed")
    }
}
