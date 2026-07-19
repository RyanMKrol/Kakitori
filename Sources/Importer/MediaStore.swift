import Foundation

struct MediaStore {
    let baseURL: URL

    static var defaultBaseURL: URL {
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return (appSupport ?? FileManager.default.temporaryDirectory).appendingPathComponent("Kakitori")
    }

    func mediaDirectory(for deckID: UUID) -> URL {
        baseURL.appendingPathComponent("Media").appendingPathComponent(deckID.uuidString)
    }

    /// Read an Anki `.apkg` media manifest (a JSON object mapping payload key -> real filename).
    static func readManifest(at manifestURL: URL) throws -> [String: String] {
        let manifestData = try Data(contentsOf: manifestURL)
        guard let manifest = (try? JSONSerialization.jsonObject(with: manifestData)) as? [String: String] else {
            throw MediaStoreError.badManifest
        }
        return manifest
    }

    @discardableResult
    func copyMedia(manifestURL: URL, payloadDirectory: URL, deckID: UUID) throws -> [String] {
        let manifest = try MediaStore.readManifest(at: manifestURL)
        return try copyMedia(manifest: manifest, payloadDirectory: payloadDirectory, deckID: deckID)
    }

    /// Copy exactly the payload files named by `manifest` into the deck's media directory. Pass a
    /// FILTERED manifest (e.g. only one split deck's referenced audio) to copy just those files.
    @discardableResult
    func copyMedia(manifest: [String: String], payloadDirectory: URL, deckID: UUID) throws -> [String] {
        // Create the media directory with intermediate directories
        let mediaDir = mediaDirectory(for: deckID)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        var copiedFiles: [String] = []

        // Process each manifest entry
        for (key, realFilename) in manifest {
            let sourceURL = payloadDirectory.appendingPathComponent(key)

            // Skip if source file doesn't exist
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                continue
            }

            let destURL = mediaDir.appendingPathComponent(realFilename)

            // If destination exists, remove it first (overwrite by name)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }

            // Copy the file
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            copiedFiles.append(realFilename)
        }

        return copiedFiles
    }
}

enum MediaStoreError: Error, Equatable {
    case badManifest
}
