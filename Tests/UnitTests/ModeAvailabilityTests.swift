@testable import Kakitori
import XCTest

final class ModeAvailabilityTests: XCTestCase {
    func testDeckModesHiraganaOnly() {
        let modes = ModeAvailability.deckModes(scripts: [.hiragana])
        XCTAssertEqual(modes, [.trace, .listen, .mixed])
    }

    func testDeckModesKatakanaOnly() {
        let modes = ModeAvailability.deckModes(scripts: [.katakana])
        XCTAssertEqual(modes, [.trace, .listen, .mixed])
    }

    func testDeckModesHiraganaAndKatakana() {
        let modes = ModeAvailability.deckModes(scripts: [.hiragana, .katakana])
        XCTAssertEqual(modes, [.trace, .listen, .mixed])
    }

    func testDeckModesKanjiOnly() {
        let modes = ModeAvailability.deckModes(scripts: [.kanji])
        XCTAssertEqual(modes, [.trace, .listen, .translate, .mixed])
    }

    func testDeckModesKanjiAndMixed() {
        let modes = ModeAvailability.deckModes(scripts: [.kanji, .mixed])
        XCTAssertEqual(modes, [.trace, .listen, .translate, .mixed])
    }

    func testCardQualifiesListenWithAudio() {
        XCTAssertTrue(
            ModeAvailability.cardQualifies(.listen, hasAudio: true, ttsAvailable: false, english: nil)
        )
    }

    func testCardQualifiesListenWithTTS() {
        XCTAssertTrue(
            ModeAvailability.cardQualifies(.listen, hasAudio: false, ttsAvailable: true, english: nil)
        )
    }

    func testCardQualifiesListenWithBoth() {
        XCTAssertTrue(
            ModeAvailability.cardQualifies(.listen, hasAudio: true, ttsAvailable: true, english: nil)
        )
    }

    func testCardQualifiesListenWithNeither() {
        XCTAssertFalse(
            ModeAvailability.cardQualifies(.listen, hasAudio: false, ttsAvailable: false, english: nil)
        )
    }

    func testCardQualifiesTranslateWithNilEnglish() {
        XCTAssertFalse(
            ModeAvailability.cardQualifies(.translate, hasAudio: true, ttsAvailable: true, english: nil)
        )
    }

    func testCardQualifiesTranslateWithEmptyEnglish() {
        XCTAssertFalse(
            ModeAvailability.cardQualifies(.translate, hasAudio: true, ttsAvailable: true, english: "")
        )
    }

    func testCardQualifiesTranslateWithWhitespaceEnglish() {
        XCTAssertFalse(
            ModeAvailability.cardQualifies(.translate, hasAudio: true, ttsAvailable: true, english: "  ")
        )
    }

    func testCardQualifiesTranslateWithNewlineEnglish() {
        XCTAssertFalse(
            ModeAvailability.cardQualifies(.translate, hasAudio: true, ttsAvailable: true, english: "\n")
        )
    }

    func testCardQualifiesTranslateWithValidEnglish() {
        XCTAssertTrue(
            ModeAvailability.cardQualifies(.translate, hasAudio: true, ttsAvailable: true, english: "Good morning.")
        )
    }

    func testCardQualifiesTraceAlwaysQualifies() {
        XCTAssertTrue(
            ModeAvailability.cardQualifies(.trace, hasAudio: false, ttsAvailable: false, english: nil)
        )
    }

    func testCardQualifiesMixedAlwaysQualifies() {
        XCTAssertTrue(
            ModeAvailability.cardQualifies(.mixed, hasAudio: false, ttsAvailable: false, english: nil)
        )
    }
}
