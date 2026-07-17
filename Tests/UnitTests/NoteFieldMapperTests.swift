@testable import Kakitori
import XCTest

final class NoteFieldMapperTests: XCTestCase {
    func testCanonicalOrderMapping() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-1",
            modelID: 1,
            fields: ["おはよう", "ohayō", "Good morning.", "Greetings", "", "", "[sound:a1.mp3]"],
            tags: "",
            deckID: 42
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.ankiGUID, "test-guid-1")
        XCTAssertEqual(mapped.ankiDeckID, 42)
        XCTAssertEqual(mapped.target, "おはよう")
        XCTAssertEqual(mapped.pronunciation, "ohayō")
        XCTAssertEqual(mapped.english, "Good morning.")
        XCTAssertEqual(mapped.category, "Greetings")
        XCTAssertNil(mapped.hint)
        XCTAssertNil(mapped.image)
        XCTAssertEqual(mapped.audioFilename, "a1.mp3")
    }

    func testReorderedModelMapping() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Audio", "English", "Target"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-2",
            modelID: 1,
            fields: ["[sound:a1.mp3]", "Good morning.", "おはよう"],
            tags: "",
            deckID: 42
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.target, "おはよう")
        XCTAssertEqual(mapped.english, "Good morning.")
        XCTAssertEqual(mapped.audioFilename, "a1.mp3")
        XCTAssertNil(mapped.pronunciation)
        XCTAssertNil(mapped.category)
    }

    func testHTMLCleaning() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-3",
            modelID: 1,
            fields: ["<b>ね</b>&amp;<br>next", "", "", "", "", "", ""],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.target, "ね& next")
    }

    func testEmptyAudioField() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-4",
            modelID: 1,
            fields: ["おはよう", "", "", "", "", "", ""],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertNil(mapped.audioFilename)
    }

    func testEmptyTargetThrows() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-5",
            modelID: 1,
            fields: ["   ", "", "", "", "", "", ""],
            tags: "",
            deckID: nil
        )

        XCTAssertThrowsError(
            try NoteFieldMapper.map(note, using: model),
            "Should throw emptyTarget error"
        ) { error in
            XCTAssertEqual(error as? NoteFieldMapperError, .emptyTarget(noteID: 100))
        }
    }

    func testMissingFieldsGracefulDegradation() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-6",
            modelID: 1,
            fields: ["おはよう", "ohayō"],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.target, "おはよう")
        XCTAssertEqual(mapped.pronunciation, "ohayō")
        XCTAssertNil(mapped.english)
        XCTAssertNil(mapped.category)
        XCTAssertNil(mapped.hint)
        XCTAssertNil(mapped.image)
        XCTAssertNil(mapped.audioFilename)
    }

    func testHTMLEntitiesDecode() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-7",
            modelID: 1,
            fields: ["&lt;tag&gt;&quot;quote&quot;&nbsp;test&#39;s", "", "", "", "", "", ""],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.target, "<tag>\"quote\" test's")
    }

    func testMultipleBrTags() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-8",
            modelID: 1,
            fields: ["line1<br>line2<br/>line3<br />line4", "", "", "", "", "", ""],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.target, "line1 line2 line3 line4")
    }

    func testAudioFilenameExtraction() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-9",
            modelID: 1,
            fields: ["おはよう", "", "", "", "", "", "some text [sound:bc4e77e6407e004b.mp3] more text"],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.audioFilename, "bc4e77e6407e004b.mp3")
    }

    func testAudioFilenameWithoutSoundTag() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-10",
            modelID: 1,
            fields: ["おはよう", "", "", "", "", "", "just plain text"],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertNil(mapped.audioFilename)
    }

    func testWhitespaceTrimmingInCleanedFields() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-11",
            modelID: 1,
            fields: ["  \n  おはよう  \n  ", "  ohayō  ", "  Good morning.  ", "", "", "", ""],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.target, "おはよう")
        XCTAssertEqual(mapped.pronunciation, "ohayō")
        XCTAssertEqual(mapped.english, "Good morning.")
    }

    func testDivAndPTagsReplacement() throws {
        let model = AnkiModel(
            id: 1,
            name: "KakitoriNote",
            fieldNames: ["Target", "Pronunciation", "English", "Category", "Hint", "Image", "Audio"]
        )

        let note = AnkiNote(
            id: 100,
            guid: "test-guid-12",
            modelID: 1,
            fields: ["<div>hello</div><p>world</p>", "", "", "", "", "", ""],
            tags: "",
            deckID: nil
        )

        let mapped = try NoteFieldMapper.map(note, using: model)

        XCTAssertEqual(mapped.target, "hello world")
    }

    func testMappedNoteEquatable() {
        let note1 = MappedNote(
            ankiGUID: "guid1",
            ankiDeckID: 42,
            target: "target",
            pronunciation: "pron",
            english: "eng",
            category: "cat",
            hint: "hint",
            image: "img",
            audioFilename: "audio.mp3"
        )

        let note2 = MappedNote(
            ankiGUID: "guid1",
            ankiDeckID: 42,
            target: "target",
            pronunciation: "pron",
            english: "eng",
            category: "cat",
            hint: "hint",
            image: "img",
            audioFilename: "audio.mp3"
        )

        XCTAssertEqual(note1, note2)
    }
}
