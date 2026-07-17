@testable import Kakitori
import XCTest

final class TargetSegmenterTests: XCTestCase {
    func testPureHiragana() {
        let target = "ありがとう"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("あ"),
            .box("り"),
            .box("が"),
            .box("と"),
            .box("う"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .hiragana)
    }

    func testPureKatakana() {
        let target = "カメラ"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("カ"),
            .box("メ"),
            .box("ラ"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .katakana)
    }

    func testPureKanji() {
        let target = "日本語"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("日"),
            .box("本"),
            .box("語"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .kanji)
    }

    func testMixedScript() {
        let target = "お名前"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("お"),
            .box("名"),
            .box("前"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .mixed)
    }

    func testWithPunctuation() {
        let target = "おはようございます。"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("お"),
            .box("は"),
            .box("よ"),
            .box("う"),
            .box("ご"),
            .box("ざ"),
            .box("い"),
            .box("ま"),
            .box("す"),
            .inline("。"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .hiragana)
    }

    func testKatakanaWithChouon() {
        let target = "コーヒー"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("コ"),
            .inline("ー"),
            .box("ヒ"),
            .inline("ー"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .katakana)
    }

    func testLongPhraseWithPunctuation() {
        let target = "はじめまして、どうぞよろしく。"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("は"),
            .box("じ"),
            .box("め"),
            .box("ま"),
            .box("し"),
            .box("て"),
            .inline("、"),
            .box("ど"),
            .box("う"),
            .box("ぞ"),
            .box("よ"),
            .box("ろ"),
            .box("し"),
            .box("く"),
            .inline("。"),
        ])

        let boxCount = result.count(where: { if case .box = $0 { true } else { false } })
        XCTAssertEqual(boxCount, 13)

        XCTAssertEqual(result.count, 15)

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .hiragana)
    }

    func testAllPunctuationMarks() {
        let punctuationMarks = ["。", "、", "！", "？", "・", "ー"]

        for mark in punctuationMarks {
            let target = "あ\(mark)い"
            let result = TargetSegmenter.segment(target)

            XCTAssertEqual(result, [
                .box("あ"),
                .inline(mark),
                .box("い"),
            ], "Failed for punctuation mark: \(mark)")
        }
    }

    func testWhitespaceDropped() {
        let target = "あ い う"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("あ"),
            .box("い"),
            .box("う"),
        ])
    }

    func testNewlineDropped() {
        let target = "あ\nい\nう"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("あ"),
            .box("い"),
            .box("う"),
        ])
    }

    func testEmptyString() {
        let target = ""
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .mixed)
    }

    func testOnlyWhitespace() {
        let target = "   \n  \t  "
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .mixed)
    }

    func testOnlyPunctuation() {
        let target = "。、"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .inline("。"),
            .inline("、"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .mixed)
    }

    func testMixedWithLatin() {
        let target = "あAい"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("あ"),
            .box("A"),
            .box("い"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .mixed)
    }

    func testMixedWithDigits() {
        let target = "あ1い"
        let result = TargetSegmenter.segment(target)

        XCTAssertEqual(result, [
            .box("あ"),
            .box("1"),
            .box("い"),
        ])

        let script = TargetSegmenter.classify(target)
        XCTAssertEqual(script, .mixed)
    }
}
