import Foundation
@testable import Kakitori
import SwiftData
import XCTest

/// Audio behaviour for a session: what auto-plays on the prompt, what auto-plays on reveal, and
/// what the "Audio autoplay" setting suppresses.
@MainActor
final class SessionAudioTests: SessionViewModelTestCase {
    // MARK: - Listen-mode audio autoplay

    func testListenModeAutoplaysAudioOnEntryAndOnAdvance() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let noteA = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        noteA.audioFilename = "a.mp3"
        noteA.deck = deck
        let noteB = makeReviewNote(target: "い", dueBefore: baseNow, deck: deck)
        noteB.audioFilename = "i.mp3"
        noteB.deck = deck
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .listen, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )

        // Construction alone does not auto-play — must be triggered by view appearance.
        XCTAssertEqual(viewModel.presentedMode, .listen)
        XCTAssertTrue(fake.calls.isEmpty, "audio should NOT auto-play during init()")

        // Trigger autoplay for the first card (simulates view appearing).
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertEqual(fake.calls.count, 1, "audio should auto-play when view trigger is called")

        // Advancing to the next card: grade first.
        viewModel.showAnswer()
        scripted.advance(by: 30)
        viewModel.grade(.good)
        XCTAssertEqual(viewModel.phase, .prompt, "there should be a second card to show")
        XCTAssertEqual(fake.calls.count, 1, "audio should NOT auto-play during grade()")

        // Trigger autoplay for the second card (simulates view appearing with new card id).
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertEqual(
            fake.calls.count, 2,
            "audio should auto-play again when the view trigger is called for the new card"
        )
    }

    /// The LAST card graded "Again" re-enters as the same note, so the view can't key its autoplay
    /// off the note id — it never changes. It keys off `presentationCount` instead, and autoplay is
    /// re-armed per presentation, so the card that comes back speaks again instead of sitting silent.
    func testListenModeAutoplaysAgainWhenTheLastCardReenters() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        note.audioFilename = "a.mp3"
        note.deck = deck
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .listen, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )

        let presentations = viewModel.presentationCount
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertEqual(fake.calls.count, 1)

        // "Again" on the only card in the queue puts the SAME note straight back in front of the user.
        viewModel.showAnswer()
        scripted.advance(by: 30)
        viewModel.grade(.again)
        XCTAssertEqual(viewModel.currentNote?.id, note.id)
        XCTAssertGreaterThan(viewModel.presentationCount, presentations, "the view sees a new card")

        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertEqual(fake.calls.count, 2, "the re-entered card auto-plays its audio again")
    }

    func testTraceModeDoesNotAutoplayAudio() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        note.audioFilename = "a.mp3"
        note.deck = deck
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )
        XCTAssertEqual(viewModel.presentedMode, .trace)
        XCTAssertTrue(fake.calls.isEmpty, "Trace mode does NOT auto-play during init()")

        // Even if the view trigger is called, Trace mode still does not auto-play on the PROMPT.
        // (It does on reveal — see testTraceModeAutoplaysOnReveal.)
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertTrue(fake.calls.isEmpty, "Trace mode does NOT auto-play its prompt — there is nothing to hear yet")
    }

    // MARK: - Answer-reveal audio autoplay

    /// Revealing the answer exposes a Play audio control; with autoplay on it should play itself.
    func testTraceModeAutoplaysOnReveal() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        note.audioFilename = "a.mp3"
        note.deck = deck
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertTrue(fake.calls.isEmpty, "nothing plays while the prompt is up in Trace")

        viewModel.showAnswer()
        XCTAssertEqual(fake.calls.count, 1, "revealing the answer should auto-play it")
    }

    /// Listen already played the audio as the prompt — revealing must not fire a second burst.
    func testListenModeDoesNotReplayOnReveal() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        note.audioFilename = "a.mp3"
        note.deck = deck
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .listen, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertEqual(fake.calls.count, 1, "the Listen prompt auto-plays")

        viewModel.showAnswer()
        XCTAssertEqual(fake.calls.count, 1, "revealing must NOT play a second time in Listen mode")
    }

    func testRevealAutoplayRespectsSettingOff() throws {
        UserDefaults.standard.set(false, forKey: "audioAutoplay")
        defer { UserDefaults.standard.removeObject(forKey: "audioAutoplay") }

        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        note.audioFilename = "a.mp3"
        note.deck = deck
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .trace, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )
        viewModel.showAnswer()
        XCTAssertTrue(fake.calls.isEmpty, "reveal auto-play must respect the Audio autoplay setting being off")

        // The manual Play audio control still works with autoplay off.
        viewModel.replayAudio()
        XCTAssertEqual(fake.calls.count, 1, "tapping Play audio must still work when autoplay is off")
    }

    func testTranslateModeDoesNotAutoplay() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        // A kanji note with English so Translate qualifies.
        let note = Note(target: "火", pronunciation: "ひ", english: "fire", script: .kanji)
        let schedule = CardSchedule(state: .review, dueAt: baseNow.addingTimeInterval(-3600))
        note.schedule = schedule
        note.audioFilename = "hi.mp3"
        note.deck = deck
        deck.sections[0].notes.append(note)
        modelContext.insert(note)
        modelContext.insert(schedule)
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .translate, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )
        XCTAssertEqual(viewModel.presentedMode, .translate)
        XCTAssertTrue(fake.calls.isEmpty, "Translate must NOT auto-play — it would give away the answer")
    }

    func testAutoplayDoesNotFireWhenDisabled() throws {
        UserDefaults.standard.set(false, forKey: "audioAutoplay")
        defer { UserDefaults.standard.removeObject(forKey: "audioAutoplay") }

        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()
        let note = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        note.audioFilename = "a.mp3"
        note.deck = deck
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .listen, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )
        XCTAssertTrue(fake.calls.isEmpty, "auto-play must respect the Audio autoplay setting being off")

        // Even if the view trigger is called, autoplay setting off prevents playback.
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertTrue(fake.calls.isEmpty, "auto-play must respect the Audio autoplay setting being off")
    }

    // MARK: - Regression: autoplay fires exactly once per card

    func testListenModeAutoplayFiresExactlyOncePerCardRealPath() throws {
        let scripted = ScriptedClock(baseNow)
        let clock = makeClock(scripted)
        let deck = makeDeck()

        let noteA = makeReviewNote(target: "あ", dueBefore: baseNow, deck: deck)
        noteA.audioFilename = "a.mp3"
        noteA.deck = deck
        let noteB = makeReviewNote(target: "い", dueBefore: baseNow, deck: deck)
        noteB.audioFilename = "i.mp3"
        noteB.deck = deck
        try modelContext.save()

        let fake = FakeAudioPlayer()
        let viewModel = SessionViewModel(
            deck: deck, mode: .listen, modelContext: modelContext, clock: clock, seed: 42, audio: fake
        )

        // Init does NOT auto-play (no view trigger yet).
        XCTAssertEqual(viewModel.presentedMode, .listen)
        XCTAssertTrue(fake.calls.isEmpty, "audio should NOT auto-play during init()")

        // Simulate the view appearing (after settle delay): exactly one autoplay for first card.
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertEqual(fake.calls.count, 1, "REGRESSION: first card should autoplay exactly once")

        // Grade and advance to the next card.
        viewModel.showAnswer()
        scripted.advance(by: 30)
        viewModel.grade(.good)
        XCTAssertEqual(viewModel.phase, .prompt, "there should be a second card to show")

        // During grade/advance, hasAutoplayed is reset and presentedMode updated, but NO audio yet.
        XCTAssertEqual(fake.calls.count, 1, "audio should NOT auto-play during grade/advance")
        XCTAssertEqual(viewModel.presentedMode, .listen, "second card is also review, stays listen")

        // Simulate the second card's view appearing: exactly one MORE autoplay (total 2).
        viewModel.triggerAutoplayOnCardAppearance()
        XCTAssertEqual(fake.calls.count, 2, "REGRESSION: second card should autoplay exactly once, total 2")
    }
}
