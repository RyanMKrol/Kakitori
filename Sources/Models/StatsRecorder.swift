import Foundation
import SwiftData

@MainActor
enum StatsRecorder {
    /// Records a grade, updating the daily stats for the adjusted day.
    /// - Parameters:
    ///   - previousState: The card's CardState BEFORE the grade was applied.
    ///   - now: The current time.
    ///   - deckKey: The studied deck's stable `Deck.sourceDeckName` — records against ONLY that
    ///     deck's row so studying one deck never changes another deck's daily progress.
    ///   - context: The SwiftData ModelContext to use for fetching/inserting the DailyStats.
    static func recordGrade(
        previousState: CardState,
        now: Date,
        deckKey: String? = nil,
        in context: ModelContext
    ) throws {
        let clock = AppClock.system
        let dayKey = clock.adjustedDay(for: now)
        let dailyStats = try fetchOrCreateDailyStats(for: dayKey, deckKey: deckKey, in: context)

        dailyStats.cardsWritten += 1

        if previousState == .new {
            dailyStats.newIntroduced += 1
        } else if previousState == .review {
            dailyStats.reviewsDone += 1
        }
    }

    /// Records study time, updating the daily stats for the adjusted day.
    /// - Parameters:
    ///   - seconds: The number of seconds studied.
    ///   - now: The current time.
    ///   - deckKey: The studied deck's stable `Deck.sourceDeckName`.
    ///   - context: The SwiftData ModelContext to use for fetching/inserting the DailyStats.
    static func recordStudySeconds(
        _ seconds: Int,
        now: Date,
        deckKey: String? = nil,
        in context: ModelContext
    ) throws {
        let clock = AppClock.system
        let dayKey = clock.adjustedDay(for: now)
        let dailyStats = try fetchOrCreateDailyStats(for: dayKey, deckKey: deckKey, in: context)

        dailyStats.secondsStudied += seconds
    }

    /// Ensure the (today, deck) `DailyStats` row exists and SNAPSHOT the deck's `dailyTarget` — the
    /// number of cards to practise today (unified-progress). The snapshot is taken with nothing done
    /// yet, so it's the full fresh quota and never shrinks as cards are completed.
    ///
    /// An existing row's target is RAISED if the current daily limits now allow more than it was
    /// snapshotted with — raise the new-cards limit at lunchtime and today's target grows to match,
    /// rather than staying stuck on the number the day started with. It is never lowered: the target
    /// is the denominator of a progress bar, and shrinking it mid-day can put completed above total
    /// and would walk the bar backwards. Recomputing costs nothing when the limits haven't moved —
    /// cards finished today are no longer due, so the fresh quota only comes out larger when the
    /// limits themselves grew.
    @discardableResult
    static func ensureDailyStats(
        for deck: Deck,
        now: Date,
        newPerDay: Int,
        maxReviewsPerDay: Int,
        in context: ModelContext
    ) throws -> DailyStats {
        let clock = AppClock.system
        let dayKey = clock.adjustedDay(for: now)
        let deckKey: String? = deck.sourceDeckName

        let target = DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: clock.endOfToday(after: now),
            newPerDay: newPerDay,
            maxReviewsPerDay: maxReviewsPerDay,
            newIntroducedToday: 0,
            reviewsDoneToday: 0
        ).total

        var descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.day == dayKey && $0.deckKey == deckKey }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            // Cards already finished today are part of the day's work, so they count towards the
            // raised target rather than being added on top of it.
            existing.dailyTarget = max(existing.dailyTarget, target + existing.completedToday)
            return existing
        }

        let row = DailyStats(day: dayKey, deckKey: deckKey, dailyTarget: target)
        context.insert(row)
        return row
    }

    /// Mark a card finished for the day (graded anything but "Again"). Distinct per card per day, so
    /// re-grading an already-finished card doesn't double-count. `completedToday` = `completedCardIDs.count`.
    static func recordCompletion(
        cardID: UUID,
        deckKey: String? = nil,
        now: Date,
        in context: ModelContext
    ) throws {
        let clock = AppClock.system
        let dayKey = clock.adjustedDay(for: now)
        let row = try fetchOrCreateDailyStats(for: dayKey, deckKey: deckKey, in: context)
        let idString = cardID.uuidString
        if !row.completedCardIDs.contains(idString) {
            row.completedCardIDs.append(idString)
        }
    }

    private static func fetchOrCreateDailyStats(
        for dayKey: String,
        deckKey: String?,
        in context: ModelContext
    ) throws -> DailyStats {
        var fetchDescriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.day == dayKey && $0.deckKey == deckKey }
        )
        fetchDescriptor.fetchLimit = 1

        if let existing = try context.fetch(fetchDescriptor).first {
            return existing
        }

        let newStats = DailyStats(day: dayKey, deckKey: deckKey)
        context.insert(newStats)
        return newStats
    }
}
