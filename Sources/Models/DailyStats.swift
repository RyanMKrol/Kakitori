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

    init(
        day: String,
        cardsWritten: Int = 0,
        newIntroduced: Int = 0,
        reviewsDone: Int = 0,
        secondsStudied: Int = 0,
        deckKey: String? = nil
    ) {
        self.day = day
        self.cardsWritten = cardsWritten
        self.newIntroduced = newIntroduced
        self.reviewsDone = reviewsDone
        self.secondsStudied = secondsStudied
        self.deckKey = deckKey
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
