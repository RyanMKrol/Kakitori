import Foundation
@testable import Kakitori
import SwiftData
import XCTest

final class ApkgReimportTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeImporter(container: ModelContainer) -> ApkgImporter {
        let mediaBaseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return ApkgImporter(container: container, mediaBaseURL: mediaBaseURL)
    }

    func testReimportIsIdempotent() async throws {
        let container = try makeInMemoryContainer()
        let importer = makeImporter(container: container)

        try await importer.importDeck(from: Fixture.kanaDeckURL)
        try await importer.importDeck(from: Fixture.kanaDeckURL)

        let context = ModelContext(container)
        let decks = try context.fetch(FetchDescriptor<Deck>())
        XCTAssertEqual(decks.count, 1)

        let notes = try context.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(notes.count, 114)
        XCTAssertEqual(Set(notes.map(\.id)).count, 114)
        for note in notes {
            XCTAssertFalse(note.isSoftDeleted)
        }
    }

    func testSchedulingSurvivesReimport() async throws {
        let container = try makeInMemoryContainer()
        let importer = makeImporter(container: container)

        try await importer.importDeck(from: Fixture.kanaDeckURL)

        let distinctiveDueAt = Date(timeIntervalSince1970: 4_102_444_800)
        let mutatedNoteID: UUID
        do {
            let context = ModelContext(container)
            guard let target = try context.fetch(FetchDescriptor<Note>()).first else {
                XCTFail("Expected at least one note after first import")
                return
            }
            mutatedNoteID = target.id
            target.schedule?.state = .review
            target.schedule?.intervalDays = 5
            target.schedule?.easeFactor = 2.6
            target.schedule?.dueAt = distinctiveDueAt
            try context.save()
        }

        try await importer.importDeck(from: Fixture.kanaDeckURL)

        let context = ModelContext(container)
        let notes = try context.fetch(FetchDescriptor<Note>())
        guard let mutated = notes.first(where: { $0.id == mutatedNoteID }) else {
            XCTFail("Expected mutated note to survive re-import")
            return
        }

        XCTAssertEqual(mutated.schedule?.state, .review)
        XCTAssertEqual(mutated.schedule?.intervalDays, 5)
        XCTAssertEqual(mutated.schedule?.easeFactor, 2.6)
        XCTAssertEqual(mutated.schedule?.dueAt, distinctiveDueAt)

        for note in notes where note.id != mutatedNoteID {
            XCTAssertEqual(note.schedule?.state, .new)
            XCTAssertNil(note.schedule?.dueAt)
        }
    }

    func testSoftDeleteThenRevival() async throws {
        let container = try makeInMemoryContainer()
        let importer = makeImporter(container: container)

        try await importer.importDeck(from: Fixture.kanaDeckURL)

        let fullParsed = try await importer.parse(url: Fixture.kanaDeckURL)
        defer { try? FileManager.default.removeItem(at: fullParsed.extractionDirectory) }

        guard let droppedGUID = fullParsed.notes.last?.ankiGUID else {
            XCTFail("Expected at least one parsed note")
            return
        }
        let doctored = ParsedDeck(
            deckName: fullParsed.deckName,
            notes: Array(fullParsed.notes.dropLast()),
            extractionDirectory: fullParsed.extractionDirectory
        )

        _ = try await importer.apply(doctored)

        let droppedID = NoteIdentity.uuid(forAnkiGUID: droppedGUID)
        let context = ModelContext(container)
        let notes = try context.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(notes.count, 114)

        guard let droppedNote = notes.first(where: { $0.id == droppedID }) else {
            XCTFail("Dropped note should still exist as a soft-deleted row")
            return
        }
        XCTAssertTrue(droppedNote.isSoftDeleted)
        XCTAssertNotNil(droppedNote.schedule)
        XCTAssertEqual(notes.count(where: { !$0.isSoftDeleted }), 113)

        let revivalParsed = try await importer.parse(url: Fixture.kanaDeckURL)
        defer { try? FileManager.default.removeItem(at: revivalParsed.extractionDirectory) }
        _ = try await importer.apply(revivalParsed)

        let revivalContext = ModelContext(container)
        let notesAfterRevival = try revivalContext.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(notesAfterRevival.count, 114)

        guard let revivedNote = notesAfterRevival.first(where: { $0.id == droppedID }) else {
            XCTFail("Revived note should exist")
            return
        }
        XCTAssertFalse(revivedNote.isSoftDeleted)
    }

    func testMediaIsCopiedAndStableAcrossReimport() async throws {
        let container = try makeInMemoryContainer()
        let mediaBaseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let importer = ApkgImporter(container: container, mediaBaseURL: mediaBaseURL)

        try await importer.importDeck(from: Fixture.kanaDeckURL)

        let context = ModelContext(container)
        guard let deck = try context.fetch(FetchDescriptor<Deck>()).first else {
            XCTFail("Expected a deck after import")
            return
        }

        let mediaDir = MediaStore(baseURL: mediaBaseURL).mediaDirectory(for: deck.id)
        let filesAfterFirst = try FileManager.default.contentsOfDirectory(atPath: mediaDir.path)
        XCTAssertTrue(filesAfterFirst.contains { $0.hasSuffix(".mp3") })

        try await importer.importDeck(from: Fixture.kanaDeckURL)

        let filesAfterSecond = try FileManager.default.contentsOfDirectory(atPath: mediaDir.path)
        XCTAssertEqual(filesAfterFirst.count, filesAfterSecond.count)
    }
}
