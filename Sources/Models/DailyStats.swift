import Foundation
import SwiftData

@Model
final class DailyStats {
    var day: String
    var cardsWritten: Int
    var newIntroduced: Int
    var reviewsDone: Int
    var secondsStudied: Int
    /// The studied deck's stable `Deck.sourceDeckName`. `nil` means either a legacy
    /// pre-per-deck row (additive migration backfill) or the whole-app aggregate — callers that
    /// want per-deck isolation must match on both `day` AND `deckKey`.
    var deckKey: String?

    /// Unified daily progress (docs: unified-progress design). `dailyTarget` (Y) is the number of
    /// cards this deck asks the user to practise today — snapshotted ONCE at the start of the day,
    /// when nothing is done, so it never shrinks as cards are completed. `completedCardIDs` holds
    /// the ids of cards finished today (graded anything but "Again", once per card per day).
    /// The deck card, in-session bar, and Home banner all derive from this pair.
    var dailyTarget: Int = 0
    var completedCardIDs: [String] = []

    /// Cards finished today for this deck (distinct, mode-independent). The X of X/Y.
    var completedToday: Int {
        completedCardIDs.count
    }

    /// Cards still to do today for this deck, never negative. Y − X.
    var remainingToday: Int {
        max(0, dailyTarget - completedToday)
    }

    /// True once the day's target has been met (or there was nothing to do).
    var isDayComplete: Bool {
        completedToday >= dailyTarget
    }

    init(
        day: String,
        cardsWritten: Int = 0,
        newIntroduced: Int = 0,
        reviewsDone: Int = 0,
        secondsStudied: Int = 0,
        deckKey: String? = nil,
        dailyTarget: Int = 0,
        completedCardIDs: [String] = []
    ) {
        self.day = day
        self.cardsWritten = cardsWritten
        self.newIntroduced = newIntroduced
        self.reviewsDone = reviewsDone
        self.secondsStudied = secondsStudied
        self.deckKey = deckKey
        self.dailyTarget = dailyTarget
        self.completedCardIDs = completedCardIDs
    }

    /// Consecutive active days ending at today, or at yesterday if today isn't active yet
    /// (docs/02-product-spec.md §4.3 — the streak isn't shown as broken until the day passes).
    static func currentStreak(activeDays: Set<String>, now: Date, clock: AppClock) -> Int {
        let today = clock.adjustedDay(for: now)

        var cursor = now
        if !activeDays.contains(today) {
            guard let yesterday = clock.calendar.date(byAdding: .day, value: -1, to: now) else {
                return 0
            }
            guard activeDays.contains(clock.adjustedDay(for: yesterday)) else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while activeDays.contains(clock.adjustedDay(for: cursor)) {
            streak += 1
            guard let previous = clock.calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return streak
    }
}
