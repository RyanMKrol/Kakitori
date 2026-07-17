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

    @discardableResult
    func copyMedia(manifestURL: URL, payloadDirectory: URL, deckID: UUID) throws -> [String] {
        // Parse the manifest
        let manifestData = try Data(contentsOf: manifestURL)
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: manifestData)
        } catch {
            throw MediaStoreError.badManifest
        }
        guard let manifest = jsonObject as? [String: String] else {
            throw MediaStoreError.badManifest
        }

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
