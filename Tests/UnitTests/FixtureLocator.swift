import Foundation

enum Fixture {
    static var kanaDeckURL: URL {
        let moduleBundle = Bundle(for: FixtureHelper.self)

        if let resourceURL = moduleBundle.url(forResource: "kana-deck-v5", withExtension: "apkg") {
            return resourceURL
        }

        let fileURL = URL(fileURLWithPath: #filePath)
        return fileURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("kana-deck-v5.apkg")
    }
}

private class FixtureHelper {}
