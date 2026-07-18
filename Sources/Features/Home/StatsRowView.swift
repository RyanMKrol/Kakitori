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

    private var writtenTodayValue: String {
        let today = AppClock.system.today
        let todayStats = allStats.first { $0.day == today }
        return String(todayStats?.cardsWritten ?? 0)
    }

    private var minutesValue: String {
        let today = AppClock.system.today
        let todayStats = allStats.first { $0.day == today }
        let minutes = (todayStats?.secondsStudied ?? 0) / 60
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
                        .font(.system(size: isCompact ? 16 : 20))
                }
                Text(value)
                    .font(.system(size: isCompact ? 20 : 28, weight: .semibold, design: .default))
                    .foregroundStyle(accentColor ? KakitoriTheme.accent : KakitoriTheme.ink)
            }

            Text(caption)
                .font(KakitoriTheme.smallCapsLabel(size: 11))
                .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isCompact ? nil : 80)
        .padding(.vertical, isCompact ? 12 : 0)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 16 : 18))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 16 : 18)
                .stroke(KakitoriTheme.boxLine, lineWidth: 1)
        )
    }
}
