import SwiftData
import SwiftUI

struct StatsRowView: View {
    @Query private var allStats: [DailyStats]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                value: streakValue,
                caption: isCompact ? "Streak" : "Day streak",
                prefix: "🔥",
                accentColor: true,
                isCompact: isCompact
            )

            StatCard(
                value: writtenTodayValue,
                caption: isCompact ? "Written" : "Written today",
                prefix: nil,
                accentColor: false,
                isCompact: isCompact
            )

            StatCard(
                value: minutesValue,
                caption: isCompact ? "Studied" : "Minutes studied",
                prefix: nil,
                accentColor: false,
                isCompact: isCompact
            )
        }
        .padding(.horizontal)
    }

    private var streakValue: String {
        let activeDays = Set(allStats.map(\.day))
        let streak = DailyStats.currentStreak(
            activeDays: activeDays,
            now: AppClock.system.now(),
            clock: AppClock.system
        )
        return String(streak)
    }

    /// Sums across all of today's per-deck rows (plus any legacy global row) — these stats stay
    /// whole-app even though `DailyStats` is now keyed per deck.
    private var todayStats: [DailyStats] {
        let today = AppClock.system.today
        return allStats.filter { $0.day == today }
    }

    private var writtenTodayValue: String {
        String(todayStats.reduce(0) { $0 + $1.cardsWritten })
    }

    private var minutesValue: String {
        let minutes = todayStats.reduce(0) { $0 + $1.secondsStudied } / 60
        return "\(minutes)m"
    }
}

private struct StatCard: View {
    let value: String
    let caption: String
    let prefix: String?
    let accentColor: Bool
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 4 : 8) {
            HStack(spacing: 4) {
                if let prefix {
                    Text(prefix)
                        .kakitoriFont(size: isCompact ? 16 : 20)
                }
                Text(value)
                    .kakitoriFont(size: isCompact ? 20 : 28, weight: .semibold)
                    .foregroundStyle(accentColor ? KakitoriTheme.accent : KakitoriTheme.ink)
            }

            Text(caption)
                .kakitoriFont(size: 11, weight: .semibold)
                .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isCompact ? nil : 80)
        .padding(.vertical, isCompact ? 12 : 0)
        .background(KakitoriTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 16 : 18))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 16 : 18)
                .stroke(KakitoriTheme.boxLine, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(caption)")
    }
}
