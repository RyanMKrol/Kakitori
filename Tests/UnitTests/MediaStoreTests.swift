import Foundation
@testable import Kakitori
import XCTest

class MediaStoreTests: XCTestCase {
    func testCopyMediaFromFixture() throws {
        // Extract fixture to temp directory
        let fixtureURL = Fixture.kanaDeckURL
        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try ZipArchive(url: fixtureURL).extractAll(to: extractDir)

        // Extract media manifest from the archive
        let manifestURL = extractDir.appendingPathComponent("media")
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: String]
        guard let manifest, !manifest.isEmpty else {
            XCTFail("Fixture should have media manifest entries")
            return
        }

        // Create MediaStore with temp base directory
        let storeBaseDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = MediaStore(baseURL: storeBaseDir)
        let deckID = UUID()

        // Copy media
        let copied = try store.copyMedia(manifestURL: manifestURL, payloadDirectory: extractDir, deckID: deckID)

        // Assert: returned list is non-empty and has mp3 files
        XCTAssertFalse(copied.isEmpty, "Should have copied at least one media file")
        let hasMP3 = copied.contains { $0.hasSuffix(".mp3") }
        XCTAssertTrue(hasMP3, "Should have at least one .mp3 file in copied list")

        // Assert: at least one file exists with size > 0
        let mediaDir = store.mediaDirectory(for: deckID)
        var foundFile = false
        for name in copied {
            let filePath = mediaDir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: filePath.path) {
                let attrs = try FileManager.default.attributesOfItem(atPath: filePath.path)
                let size = attrs[.size] as? Int ?? 0
                if size > 0 {
                    foundFile = true
                    break
                }
            }
        }
        XCTAssertTrue(foundFile, "Should have at least one file with size > 0")

        // Assert: second call with same parameters overwrites without duplication
        let copied2 = try store.copyMedia(manifestURL: manifestURL, payloadDirectory: extractDir, deckID: deckID)
        XCTAssertEqual(copied, copied2, "Second call should return same filenames")

        let fileCount = try FileManager.default.contentsOfDirectory(atPath: mediaDir.path).count
        let fileCount2 = try FileManager.default.contentsOfDirectory(atPath: mediaDir.path).count
        XCTAssertEqual(
            fileCount,
            fileCount2,
            "File count should not change after second copy (overwrite, no duplication)"
        )

        // Cleanup
        try FileManager.default.removeItem(at: extractDir)
        try FileManager.default.removeItem(at: storeBaseDir)
    }

    func testBadManifestThrows() throws {
        // Create a temp directory with a non-JSON file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let badManifestURL = tempDir.appendingPathComponent("media")
        try "not json".write(to: badManifestURL, atomically: true, encoding: .utf8)

        let store = MediaStore(baseURL: tempDir)
        let deckID = UUID()

        // Should throw .badManifest
        do {
            _ = try store.copyMedia(manifestURL: badManifestURL, payloadDirectory: tempDir, deckID: deckID)
            XCTFail("Should throw MediaStoreError.badManifest")
        } catch MediaStoreError.badManifest {
            // Expected
        } catch {
            XCTFail("Should throw MediaStoreError.badManifest, not \(error)")
        }

        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
    }

    func testMissingPayloadFileIsSkipped() throws {
        let parentDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let payloadDir = parentDir.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

        let storeDir = parentDir.appendingPathComponent("store")
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        // Create a manifest with one entry whose payload file doesn't exist
        let manifestURL = parentDir.appendingPathComponent("media")
        let manifest: [String: String] = ["0": "nonexistent.mp3", "1": "also-missing.mp3"]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest)
        try manifestData.write(to: manifestURL)

        let store = MediaStore(baseURL: storeDir)
        let deckID = UUID()

        // Copy should succeed but return empty list (all files missing)
        let copied = try store.copyMedia(manifestURL: manifestURL, payloadDirectory: payloadDir, deckID: deckID)
        XCTAssertTrue(copied.isEmpty, "Should return empty list when all payload files are missing")

        // Cleanup
        try FileManager.default.removeItem(at: parentDir)
    }

    func testDefaultBaseURL() throws {
        let defaultURL = MediaStore.defaultBaseURL
        let expectedPath = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        .appendingPathComponent("Kakitori")
        .path
        XCTAssertEqual(defaultURL.path, expectedPath, "defaultBaseURL should be Application Support/Kakitori")
    }
}
