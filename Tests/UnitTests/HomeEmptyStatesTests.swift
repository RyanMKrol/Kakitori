@testable import Kakitori
import SwiftData
import XCTest

@MainActor
final class HomeEmptyStatesTests: XCTestCase {
    // MARK: - Import error mapping

    func testImportErrorMessages() {
        XCTAssertEqual(
            ImporterError.badZip.userMessage,
            "This file could not be read as an Anki deck."
        )
        XCTAssertEqual(
            ImporterError.noAnkiBuilderModel.userMessage,
            "This deck has no field Kakitori can use as a writing target."
        )
        XCTAssertEqual(
            ImporterError.zeroNotes.userMessage,
            "This deck has no cards to import."
        )
    }

    // MARK: - Today banner all-caught-up

    func testBannerAllowanceIsZeroWhenNoneDue() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let deck = makeDeck(noteStates: [])
        let section = deck.sections[0]
        let schedule = CardSchedule(state: .review, dueAt: now.addingTimeInterval(86400))
        let note = Note(target: "あ", script: .hiragana, schedule: schedule)
        section.notes.append(note)

        let allowance = TodayBannerView.calculateAllowance(
            decks: [deck],
            dailyStats: [],
            now: now,
            clock: .fixed(now),
            settings: AppSettings()
        )
        XCTAssertEqual(allowance.total, 0)
        XCTAssertEqual(allowance.scriptCount, 0)
    }

    func testBannerAllowanceCountsNewLearningAndOverdueReview() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let deck = makeDeck(noteStates: [.new])
        let allowance = TodayBannerView.calculateAllowance(
            decks: [deck],
            dailyStats: [],
            now: now,
            clock: .fixed(now),
            settings: AppSettings()
        )
        XCTAssertEqual(allowance.total, 1)
        XCTAssertEqual(allowance.scriptCount, 1)
    }

    // MARK: - Deck card all-caught-up

    func testDeckCardIsAllCaughtUpWhenNoCountsOutstanding() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let deck = makeDeck(noteStates: [])
        let deckCard = DeckCardView(deck: deck, now: now, onStudy: { _ in })
        XCTAssertTrue(deckCard.isAllCaughtUp)
    }

    func testDeckCardIsNotAllCaughtUpWhenNewCardsExist() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let deck = makeDeck(noteStates: [.new])
        let deckCard = DeckCardView(deck: deck, now: now, onStudy: { _ in })
        XCTAssertFalse(deckCard.isAllCaughtUp)
    }

    // MARK: - Fixtures

    private func makeDeck(noteStates: [CardState]) -> Deck {
        let deck = Deck(
            name: "Hiragana",
            sourceDeckName: "Kaki::Hiragana",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        let section = Section(name: "Vowels", orderIndex: 0)
        deck.sections.append(section)

        for state in noteStates {
            let schedule = CardSchedule(state: state)
            let note = Note(target: "あ", script: .hiragana, schedule: schedule)
            section.notes.append(note)
        }

        return deck
    }
}
