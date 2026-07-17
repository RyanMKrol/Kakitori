@testable import Kakitori
import XCTest

final class AnkiCollectionTests: XCTestCase {
    func testReadKanaDeckFixture() throws {
        let zipURL = Fixture.kanaDeckURL
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let archive = try ZipArchive(url: zipURL)
        try archive.extractAll(to: tempDir)

        let dbURL = tempDir.appendingPathComponent("collection.anki2")
        let collection = try AnkiCollection(databaseURL: dbURL)

        XCTAssertEqual(collection.notes.count, 114)
    }

    func testModelsContainTargetField() throws {
        let zipURL = Fixture.kanaDeckURL
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let archive = try ZipArchive(url: zipURL)
        try archive.extractAll(to: tempDir)

        let dbURL = tempDir.appendingPathComponent("collection.anki2")
        let collection = try AnkiCollection(databaseURL: dbURL)

        let targetModel = collection.models.first { $0.fieldNames.contains("Target") }
        XCTAssertNotNil(targetModel)

        guard let model = targetModel else { return }
        let requiredFields = ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]

        for field in requiredFields {
            XCTAssertTrue(model.fieldNames.contains(field), "Model should contain '\(field)' field")
        }

        let targetIdx = try XCTUnwrap(model.fieldNames.firstIndex(of: "Target"))
        let pronunciationIdx = try XCTUnwrap(model.fieldNames.firstIndex(of: "Pronunciation"))
        let englishIdx = try XCTUnwrap(model.fieldNames.firstIndex(of: "English"))
        let categoryIdx = try XCTUnwrap(model.fieldNames.firstIndex(of: "Category"))
        let hintIdx = try XCTUnwrap(model.fieldNames.firstIndex(of: "Hint"))
        let imageIdx = try XCTUnwrap(model.fieldNames.firstIndex(of: "Image"))
        let audioIdx = try XCTUnwrap(model.fieldNames.firstIndex(of: "Audio"))

        XCTAssertLessThan(targetIdx, pronunciationIdx)
        XCTAssertLessThan(pronunciationIdx, englishIdx)
        XCTAssertLessThan(englishIdx, categoryIdx)
        XCTAssertLessThan(categoryIdx, hintIdx)
        XCTAssertLessThan(hintIdx, imageIdx)
        XCTAssertLessThan(imageIdx, audioIdx)
    }

    func testDecksContainHierarchy() throws {
        let zipURL = Fixture.kanaDeckURL
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let archive = try ZipArchive(url: zipURL)
        try archive.extractAll(to: tempDir)

        let dbURL = tempDir.appendingPathComponent("collection.anki2")
        let collection = try AnkiCollection(databaseURL: dbURL)

        XCTAssertFalse(collection.decks.isEmpty)
        let hasSeparator = collection.decks.contains { $0.name.contains("::") }
        XCTAssertTrue(hasSeparator)
    }

    func testNotesHaveCorrectFieldCounts() throws {
        let zipURL = Fixture.kanaDeckURL
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let archive = try ZipArchive(url: zipURL)
        try archive.extractAll(to: tempDir)

        let dbURL = tempDir.appendingPathComponent("collection.anki2")
        let collection = try AnkiCollection(databaseURL: dbURL)

        let modelLookup = Dictionary(uniqueKeysWithValues: collection.models.map { ($0.id, $0) })

        for note in collection.notes {
            guard let model = modelLookup[note.modelID] else {
                XCTFail("Note has invalid modelID")
                continue
            }

            XCTAssertEqual(
                note.fields.count,
                model.fieldNames.count,
                "Note \(note.id) field count mismatch"
            )
            XCTAssertNotNil(note.deckID, "Note \(note.id) should have a non-nil deckID")
        }
    }

    func testCannotOpenNonexistentFile() throws {
        let nonexistent = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).anki2")

        XCTAssertThrowsError(try AnkiCollection(databaseURL: nonexistent)) { error in
            guard let collectionError = error as? AnkiCollectionError else {
                XCTFail("Expected AnkiCollectionError, got \(type(of: error))")
                return
            }
            XCTAssertEqual(collectionError, .cannotOpen)
        }
    }
}
