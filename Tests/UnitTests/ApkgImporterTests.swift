import Foundation
@testable import Kakitori
import SwiftData
import XCTest

final class ApkgImporterTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testFirstImportUpsertsDeckAndNotes() async throws {
        let container = try makeInMemoryContainer()
        let mediaBaseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let importer = ApkgImporter(container: container, mediaBaseURL: mediaBaseURL)

        try await importer.importDeck(from: Fixture.kanaDeckURL)

        let context = ModelContext(container)

        let decks = try context.fetch(FetchDescriptor<Deck>())
        XCTAssertEqual(decks.count, 1)

        guard let deck = decks.first else {
            XCTFail("Expected one deck")
            return
        }
        XCTAssertFalse(deck.name.isEmpty)
        XCTAssertFalse(deck.sourceDeckName.isEmpty)
        XCTAssertEqual(deck.sourceDeckName, deck.name)

        let notes = try context.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(notes.count, 114)

        for note in notes {
            XCTAssertFalse(note.isDeleted)
            XCTAssertNotNil(note.schedule)
            XCTAssertEqual(note.schedule?.state, .new)
            XCTAssertFalse(note.units.isEmpty)
        }
    }

    func testNoteIdentityIsDeterministic() {
        let first = NoteIdentity.uuid(forAnkiGUID: "abc")
        let second = NoteIdentity.uuid(forAnkiGUID: "abc")
        let different = NoteIdentity.uuid(forAnkiGUID: "abd")

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
    }

    func testImportingGarbageBytesThrowsBadZip() async throws {
        let container = try makeInMemoryContainer()
        let mediaBaseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let importer = ApkgImporter(container: container, mediaBaseURL: mediaBaseURL)

        let garbageURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).apkg")
        try Data("not a zip file".utf8).write(to: garbageURL)
        defer { try? FileManager.default.removeItem(at: garbageURL) }

        do {
            try await importer.importDeck(from: garbageURL)
            XCTFail("Expected ImporterError.badZip")
        } catch let error as ImporterError {
            XCTAssertEqual(error, .badZip)
        } catch {
            XCTFail("Expected ImporterError.badZip, got \(error)")
        }
    }
}
