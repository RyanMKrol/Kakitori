import SwiftData
import SwiftUI

struct StatsRowView: View {
    @Query private var allStats: [DailyStats]

    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                value: streakValue,
                caption: "Day streak",
                prefix: "🔥",
                accentColor: true
            )

            StatCard(
                value: writtenTodayValue,
                caption: "Written today",
                prefix: nil,
                accentColor: false
            )

            StatCard(
                value: minutesValue,
                caption: "Minutes studied",
                prefix: nil,
                accentColor: false
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

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                if let prefix {
                    Text(prefix)
                        .font(.system(size: 20))
                }
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(accentColor ? KakitoriTheme.accent : KakitoriTheme.ink)
            }

            Text(caption)
                .font(KakitoriTheme.smallCapsLabel(size: 11))
                .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(KakitoriTheme.boxLine, lineWidth: 1)
        )
    }
}
