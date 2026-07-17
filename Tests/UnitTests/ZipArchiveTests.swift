@testable import Kakitori
import XCTest

final class ZipArchiveTests: XCTestCase {
    func testInitializeFromKanaDeck() throws {
        let archive = try ZipArchive(url: Fixture.kanaDeckURL)
        XCTAssertTrue(archive.entryNames.contains("collection.anki2"))
        XCTAssertTrue(archive.entryNames.contains("media"))
    }

    func testExtractAllWritesValidSQLiteHeader() throws {
        let archive = try ZipArchive(url: Fixture.kanaDeckURL)

        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent(UUID().uuidString)

        try archive.extractAll(to: testDir)

        let collectionPath = testDir.appendingPathComponent("collection.anki2")
        XCTAssertTrue(FileManager.default.fileExists(atPath: collectionPath.path))

        let data = try Data(contentsOf: collectionPath)
        let expectedHeader = Data("SQLite format 3\0".utf8)
        let actualHeader = data.subdata(in: 0 ..< 16)

        XCTAssertEqual(actualHeader, expectedHeader)

        try FileManager.default.removeItem(at: testDir)
    }

    func testExtractSingleEntryMatchesExtractAll() throws {
        let archive = try ZipArchive(url: Fixture.kanaDeckURL)

        let tempDir1 = FileManager.default.temporaryDirectory
        let testDir1 = tempDir1.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: testDir1, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir1) }

        let tempDir2 = FileManager.default.temporaryDirectory
        let testDir2 = tempDir2.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: testDir2, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir2) }

        try archive.extractAll(to: testDir1)

        let singlePath = testDir2.appendingPathComponent("collection.anki2")
        try archive.extract("collection.anki2", to: singlePath)

        let extractAllData = try Data(contentsOf: testDir1.appendingPathComponent("collection.anki2"))
        let singleExtractData = try Data(contentsOf: singlePath)

        XCTAssertEqual(extractAllData, singleExtractData)
    }

    func testInitializeWithRandomBytesThrowsNotAZip() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString)

        let randomData = Data((0 ..< 100).map { _ in UInt8.random(in: 0 ... 255) })
        try randomData.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try ZipArchive(url: tempFile)) { error in
            XCTAssertEqual(error as? ZipArchiveError, .notAZip)
        }
    }

    func testExtractNonExistentEntryThrowsNotFound() throws {
        let archive = try ZipArchive(url: Fixture.kanaDeckURL)

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString)

        XCTAssertThrowsError(try archive.extract("nope.txt", to: tempFile)) { error in
            XCTAssertEqual(error as? ZipArchiveError, .entryNotFound("nope.txt"))
        }
    }
}
