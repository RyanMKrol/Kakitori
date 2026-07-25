import Foundation
@testable import Kakitori
import SwiftData
import XCTest

/// The unified-progress additions to StatsRecorder: snapshotting a deck's fixed daily target and
/// recording distinct per-day completions.
@MainActor
final class StatsRecorderTargetTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// A deck of `count` brand-new cards.
    private func seedDeck(count: Int, context: ModelContext) -> Deck {
        let deck = Deck(name: "Hiragana", sourceDeckName: "Kakitori Foundations::Hiragana", importedAt: Date())
        let section = Section(name: "Hiragana", orderIndex: 0)
        section.deck = deck
        deck.sections.append(section)
        context.insert(deck)
        context.insert(section)
        for _ in 0 ..< count {
            let note = Note(target: "あ", script: .hiragana, deck: deck)
            note.section = section
            section.notes.append(note)
            let schedule = CardSchedule(state: .new)
            schedule.note = note
            note.schedule = schedule
            context.insert(note)
            context.insert(schedule)
        }
        return deck
    }

    func testEnsureDailyStatsSnapshotsTargetAndNeverLowersIt() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let deck = seedDeck(count: 12, context: context)
        try context.save()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let row = try StatsRecorder.ensureDailyStats(
            for: deck,
            now: now,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            in: context
        )
        // 12 new cards capped at newPerDay = 10 → target 10.
        XCTAssertEqual(row.dailyTarget, 10)

        // Same row, and a lower limit doesn't shrink today's target — it's a progress denominator,
        // and shrinking it mid-day walks the bar backwards.
        let row2 = try StatsRecorder.ensureDailyStats(
            for: deck,
            now: now,
            newPerDay: 5,
            maxReviewsPerDay: 100,
            in: context
        )
        XCTAssertEqual(row2.dailyTarget, 10, "a lowered limit must not shrink today's target")
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyStats>()).count, 1)
    }

    /// Raising the daily limit has to show up on Home the same day. It used to be snapshotted once
    /// and never revisited, so the deck card sat on "10/10 today" no matter what the setting said.
    func testRaisingTheLimitRaisesTodaysTarget() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let deck = seedDeck(count: 60, context: context)
        try context.save()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let row = try StatsRecorder.ensureDailyStats(
            for: deck, now: now, newPerDay: 10, maxReviewsPerDay: 100, in: context
        )
        XCTAssertEqual(row.dailyTarget, 10)

        let raised = try StatsRecorder.ensureDailyStats(
            for: deck, now: now, newPerDay: 50, maxReviewsPerDay: 100, in: context
        )

        XCTAssertEqual(raised.dailyTarget, 50, "today's target follows the raised limit")
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyStats>()).count, 1)
    }

    /// Cards already finished today are part of the day's work, so a raise counts them towards the
    /// new target rather than stacking the full new quota on top of what's done.
    func testRaisingTheLimitAccountsForWhatIsAlreadyDone() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let deck = seedDeck(count: 60, context: context)
        try context.save()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try StatsRecorder.ensureDailyStats(
            for: deck, now: now, newPerDay: 10, maxReviewsPerDay: 100, in: context
        )
        for _ in 0 ..< 4 {
            try StatsRecorder.recordCompletion(cardID: UUID(), deckKey: deck.sourceDeckName, now: now, in: context)
        }

        let raised = try StatsRecorder.ensureDailyStats(
            for: deck, now: now, newPerDay: 50, maxReviewsPerDay: 100, in: context
        )

        XCTAssertEqual(raised.completedToday, 4)
        XCTAssertEqual(raised.dailyTarget, 54, "the 4 done count towards the raised target, not on top of it")
        XCTAssertGreaterThan(raised.dailyTarget, raised.completedToday)
    }

    func testRecordCompletionIsDistinctPerCardPerDay() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let deck = seedDeck(count: 3, context: context)
        try context.save()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let row = try StatsRecorder.ensureDailyStats(
            for: deck,
            now: now,
            newPerDay: 10,
            maxReviewsPerDay: 100,
            in: context
        )
        let cardA = UUID()
        let cardB = UUID()

        try StatsRecorder.recordCompletion(cardID: cardA, deckKey: deck.sourceDeckName, now: now, in: context)
        XCTAssertEqual(row.completedToday, 1)

        // Same card again — no double count.
        try StatsRecorder.recordCompletion(cardID: cardA, deckKey: deck.sourceDeckName, now: now, in: context)
        XCTAssertEqual(row.completedToday, 1)

        // A different card — counts.
        try StatsRecorder.recordCompletion(cardID: cardB, deckKey: deck.sourceDeckName, now: now, in: context)
        XCTAssertEqual(row.completedToday, 2)
        XCTAssertEqual(row.remainingToday, row.dailyTarget - 2)
    }
}
