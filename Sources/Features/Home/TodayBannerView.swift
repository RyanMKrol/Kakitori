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
        let allowance = calculateAllowance()

        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY'S PRACTICE")
                .kakitoriFont(size: 11, weight: .semibold)
                .foregroundStyle(KakitoriTheme.paper.opacity(0.6))
                .tracking(0.5)

            if allowance.total > 0 {
                HStack(spacing: 2) {
                    Text("\(allowance.total) characters to write")
                        .kakitoriFont(size: 16, weight: .semibold)
                        .foregroundStyle(KakitoriTheme.paper)
                    Text(" across \(allowance.scriptCount) scripts")
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

    /// Today's allotment across all decks — the same caps a session would apply
    /// (`DailyAllowance`), not the raw uncapped backlog. Each deck's allotment is computed from
    /// its OWN daily stats row (matched by `day` and `deckKey`), then summed, so one deck hitting
    /// its cap never suppresses another deck's allotment.
    static func calculateAllowance(
        decks: [Deck],
        dailyStats: [DailyStats],
        now: Date,
        clock: AppClock,
        settings: AppSettings
    ) -> DailyAllowance {
        let today = clock.adjustedDay(for: now)
        let endOfToday = clock.endOfToday(after: now)
        let allowances = decks.map { deck -> DailyAllowance in
            let stats = dailyStats.first { $0.day == today && $0.deckKey == deck.sourceDeckName }
            return DailyAllowance.forDeck(
                deck,
                now: now,
                endOfToday: endOfToday,
                newPerDay: settings.newCardsPerDay,
                maxReviewsPerDay: settings.maxReviewsPerDay,
                newIntroducedToday: stats?.newIntroduced ?? 0,
                reviewsDoneToday: stats?.reviewsDone ?? 0
            )
        }
        return DailyAllowance.aggregate(allowances)
    }

    private func calculateAllowance() -> DailyAllowance {
        Self.calculateAllowance(decks: decks, dailyStats: dailyStats, now: now, clock: clock, settings: settings)
    }
}
