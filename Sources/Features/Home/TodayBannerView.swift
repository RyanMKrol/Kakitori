import SwiftData
import SwiftUI

struct TodayBannerView: View {
    @Query private var decks: [Deck]
    let now: Date

    var body: some View {
        let (totalDue, scriptCount) = calculateDueCards()

        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY'S PRACTICE")
                .kakitoriFont(size: 11, weight: .semibold)
                .foregroundStyle(KakitoriTheme.paper.opacity(0.6))
                .tracking(0.5)

            if totalDue > 0 {
                HStack(spacing: 2) {
                    Text("\(totalDue) characters to write")
                        .kakitoriFont(size: 16, weight: .semibold)
                        .foregroundStyle(KakitoriTheme.paper)
                    Text(" across \(scriptCount) scripts")
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

    static func calculateDueCards(decks: [Deck], now: Date) -> (Int, Int) {
        var totalDue = 0
        var scriptsWithDue = Set<Script>()

        for deck in decks {
            for section in deck.sections {
                for note in section.notes where !note.isDeleted {
                    if let schedule = note.schedule {
                        if schedule.state == .new
                            || schedule.state == .learning
                            || schedule.state == .relearning
                            || (schedule.state == .review && schedule.dueAt ?? Date.distantFuture <= now) {
                            totalDue += 1
                            scriptsWithDue.insert(note.script)
                        }
                    }
                }
            }
        }

        return (totalDue, scriptsWithDue.count)
    }

    private func calculateDueCards() -> (Int, Int) {
        Self.calculateDueCards(decks: decks, now: now)
    }
}
