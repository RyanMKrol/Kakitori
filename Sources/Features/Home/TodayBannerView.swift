import SwiftData
import SwiftUI

struct TodayBannerView: View {
    @Query private var decks: [Deck]
    let now: Date

    var body: some View {
        if let (totalDue, scriptCount) = calculateDueCards() {
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S PRACTICE")
                    .font(KakitoriTheme.smallCapsLabel(size: 11))
                    .foregroundStyle(KakitoriTheme.paper.opacity(0.6))
                    .tracking(0.5)

                HStack(spacing: 2) {
                    Text("\(totalDue) characters to write")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KakitoriTheme.paper)
                    Text(" across \(scriptCount) scripts")
                        .font(.system(size: 16))
                        .foregroundStyle(KakitoriTheme.paper.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(KakitoriTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func calculateDueCards() -> (Int, Int)? {
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

        return totalDue > 0 ? (totalDue, scriptsWithDue.count) : nil
    }
}
