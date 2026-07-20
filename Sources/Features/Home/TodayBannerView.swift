import SwiftData
import SwiftUI

struct TodayBannerView: View {
    @Query private var decks: [Deck]
    @Query private var dailyStats: [DailyStats]
    let now: Date
    let clock: AppClock
    let settings: AppSettings

    init(now: Date, clock: AppClock = .system, settings: AppSettings = AppSettings()) {
        self.now = now
        self.clock = clock
        self.settings = settings
    }

    var body: some View {
        let remaining = calculateRemaining()

        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY'S PRACTICE")
                .kakitoriFont(size: 11, weight: .semibold)
                .foregroundStyle(KakitoriTheme.paper.opacity(0.6))
                .tracking(0.5)

            if remaining.total > 0 {
                HStack(spacing: 2) {
                    Text("\(remaining.total) characters to write")
                        .kakitoriFont(size: 16, weight: .semibold)
                        .foregroundStyle(KakitoriTheme.paper)
                    Text(" across \(remaining.scriptCount) scripts")
                        .kakitoriFont(size: 16)
                        .foregroundStyle(KakitoriTheme.paper.opacity(0.8))
                }
            } else {
                Text("All caught up. Nothing due right now.")
                    .kakitoriFont(size: 16, weight: .semibold)
                    .foregroundStyle(KakitoriTheme.paper)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(KakitoriTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    /// Cards still to do today across all decks — Σ(Y − X) over each deck's fixed daily target and
    /// cards completed today (unified-progress). Each deck uses its OWN DailyStats row (matched by
    /// `day` + `deckKey`); a deck with no row yet today falls back to its fresh live allowance so it
    /// still contributes. `scriptCount` counts only scripts that still have remaining work.
    static func calculateRemaining(
        decks: [Deck],
        dailyStats: [DailyStats],
        now: Date,
        clock: AppClock,
        settings: AppSettings
    ) -> (total: Int, scriptCount: Int) {
        let today = clock.adjustedDay(for: now)
        let endOfToday = clock.endOfToday(after: now)
        var total = 0
        var scripts = Set<Script>()
        for deck in decks {
            let stats = dailyStats.first { $0.day == today && $0.deckKey == deck.sourceDeckName }
            let target: Int
            let completed: Int
            if let stats, stats.dailyTarget > 0 {
                target = stats.dailyTarget
                completed = stats.completedToday
            } else {
                target = DailyAllowance.forDeck(
                    deck,
                    now: now,
                    endOfToday: endOfToday,
                    newPerDay: settings.newCardsPerDay,
                    maxReviewsPerDay: settings.maxReviewsPerDay,
                    newIntroducedToday: 0,
                    reviewsDoneToday: 0
                ).total
                completed = 0
            }
            let deckRemaining = max(0, target - completed)
            if deckRemaining > 0 {
                total += deckRemaining
                scripts.formUnion(deck.sections.flatMap(\.notes).filter { !$0.isDeleted }.map(\.script))
            }
        }
        return (total, scripts.count)
    }

    private func calculateRemaining() -> (total: Int, scriptCount: Int) {
        Self.calculateRemaining(decks: decks, dailyStats: dailyStats, now: now, clock: clock, settings: settings)
    }
}
