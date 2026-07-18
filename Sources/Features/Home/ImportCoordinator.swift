import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ImportCoordinator {
    static let shared = ImportCoordinator()

    enum State {
        case idle
        case running(progress: Double)
        case failed(message: String)

        var isFailure: Bool {
            if case .failed = self {
                return true
            }
            return false
        }
    }

    var state: State = .idle

    private init() {}

    func begin(url: URL, modelContainer: ModelContainer, mediaBaseURL: URL) async {
        defer { url.stopAccessingSecurityScopedResource() }

        let started = url.startAccessingSecurityScopedResource()
        guard started else {
            state = .failed(message: "Failed to access the file.")
            return
        }

        state = .running(progress: 0.1)

        let importer = ApkgImporter(container: modelContainer, mediaBaseURL: mediaBaseURL)

        do {
            try await importer.importDeck(from: url)
            state = .idle
        } catch let error as ImporterError {
            let message = errorMessage(for: error)
            state = .failed(message: message)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    private func errorMessage(for error: ImporterError) -> String {
        switch error {
        case .badZip:
            "This file is not a valid .apkg archive."
        case .noAnkiBuilderModel:
            "No AnkiBuilder note type with a Target field was found in this deck."
        case .zeroNotes:
            "The deck contains no notes."
        }
    }
}
