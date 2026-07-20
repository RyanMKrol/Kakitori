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

    func testEnsureDailyStatsSnapshotsTargetOnceAndIsIdempotent() throws {
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

        // Idempotent: same row returned, target unchanged, even if we'd compute differently now.
        let row2 = try StatsRecorder.ensureDailyStats(
            for: deck,
            now: now,
            newPerDay: 5,
            maxReviewsPerDay: 100,
            in: context
        )
        XCTAssertEqual(row2.dailyTarget, 10, "the snapshot is taken once and never recomputed")
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyStats>()).count, 1)
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
