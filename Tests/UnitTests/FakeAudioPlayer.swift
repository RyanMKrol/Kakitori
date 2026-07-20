import Foundation
@testable import Kakitori

@MainActor final class FakeAudioPlayer: AudioPlaying {
    enum Call: Equatable {
        case deck(filename: String, deckID: UUID)
        case speak(String)
    }

    private(set) var calls: [Call] = []
    var isAvailable = true
    var deckAudioSucceeds = true

    @discardableResult
    func playDeckAudio(filename: String, deckID: UUID) -> Bool {
        calls.append(.deck(filename: filename, deckID: deckID))
        return deckAudioSucceeds
    }

    func speakTarget(_ target: String) {
        calls.append(.speak(target))
    }
}
