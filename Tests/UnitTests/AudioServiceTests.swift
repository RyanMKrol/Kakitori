@testable import Kakitori
import XCTest

@MainActor final class AudioServiceTests: XCTestCase {
    // MARK: - URL Resolution

    func testMediaFileURLResolution() {
        let baseURL = URL(fileURLWithPath: "/tmp/media")
        let deckIDString = "11111111-2222-3333-4444-555555555555"
        guard let deckID = UUID(uuidString: deckIDString) else {
            XCTFail("Invalid UUID")
            return
        }
        let filename = "bc4e77e6407e004b.mp3"

        let result = AudioService.mediaFileURL(filename: filename, deckID: deckID, mediaBaseURL: baseURL)

        XCTAssertEqual(result.path, "/tmp/media/11111111-2222-3333-4444-555555555555/bc4e77e6407e004b.mp3")
    }

    // MARK: - Fallback Selection

    func testPlayWithAudioFilenamePlaysAudio() {
        let fake = FakeAudioPlayer()
        let target = "おはよう"
        let filename = "a.mp3"
        let deckID = UUID()

        fake.play(target: target, audioFilename: filename, deckID: deckID)

        XCTAssertEqual(fake.calls, [.deck(filename: filename, deckID: deckID)])
    }

    func testPlayWithNilAudioFilenameSpeaks() {
        let fake = FakeAudioPlayer()
        let target = "おはよう"
        let deckID = UUID()

        fake.play(target: target, audioFilename: nil, deckID: deckID)

        XCTAssertEqual(fake.calls, [.speak(target)])
    }

    func testPlayWithEmptyAudioFilenameSpeaks() {
        let fake = FakeAudioPlayer()
        let target = "おはよう"
        let deckID = UUID()

        fake.play(target: target, audioFilename: "", deckID: deckID)

        XCTAssertEqual(fake.calls, [.speak(target)])
    }

    // MARK: - Call Ordering

    func testMultiplePlayCallsAreRecordedInOrder() {
        let fake = FakeAudioPlayer()
        let deckID = UUID()

        fake.play(target: "こんにちは", audioFilename: "a.mp3", deckID: deckID)
        fake.play(target: "さようなら", audioFilename: nil, deckID: deckID)

        XCTAssertEqual(fake.calls.count, 2)
        XCTAssertEqual(fake.calls[0], .deck(filename: "a.mp3", deckID: deckID))
        XCTAssertEqual(fake.calls[1], .speak("さようなら"))
    }

    // MARK: - No AVFoundation in Tests

    func testFakePlayerNeverCreatesAVAudioPlayer() {
        let fake = FakeAudioPlayer()
        // Just verify the fake works without crashing or trying to instantiate AVAudioPlayer.
        fake.playDeckAudio(filename: "nonexistent.mp3", deckID: UUID())
        fake.speakTarget("テスト")
        XCTAssertEqual(fake.calls.count, 2)
    }

    // MARK: - Missing Deck Audio Falls Back to Speech

    func testPlayWithPresentFilenameFallsBackToSpeechWhenDeckAudioFails() {
        let fake = FakeAudioPlayer()
        fake.deckAudioSucceeds = false
        let target = "おはよう"
        let filename = "missing.mp3"
        let deckID = UUID()

        fake.play(target: target, audioFilename: filename, deckID: deckID)

        XCTAssertEqual(fake.calls, [.deck(filename: filename, deckID: deckID), .speak(target)])
    }
}
