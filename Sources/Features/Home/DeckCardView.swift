import SwiftUI

struct DeckCardView: View {
    let deck: Deck
    let now: Date
    let endOfToday: Date
    let newIntroducedToday: Int
    let reviewsDoneToday: Int
    let settings: AppSettings
    let onStudy: (Deck) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        deck: Deck,
        now: Date,
        endOfToday: Date? = nil,
        newIntroducedToday: Int = 0,
        reviewsDoneToday: Int = 0,
        settings: AppSettings = AppSettings(),
        onStudy: @escaping (Deck) -> Void
    ) {
        self.deck = deck
        self.now = now
        self.endOfToday = endOfToday ?? AppClock.system.endOfToday(after: now)
        self.newIntroducedToday = newIntroducedToday
        self.reviewsDoneToday = reviewsDoneToday
        self.settings = settings
        self.onStudy = onStudy
    }

    var body: some View {
        if horizontalSizeClass == .compact {
            compactRow
        } else {
            regularCard
        }
    }

    private var compactRow: some View {
        Button(action: { onStudy(deck) }, label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(KakitoriTheme.ink)
                        Text(representativeGlyph)
                            .font(KakitoriTheme.japaneseDisplayFont(size: 26))
                            .foregroundStyle(KakitoriTheme.paper)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.jpTitle ?? deck.name)
                            .font(KakitoriTheme.japaneseDisplayFont(size: 17))
                            .foregroundStyle(KakitoriTheme.ink)
                            .lineLimit(1)
                        Text(deck.name)
                            .kakitoriFont(size: 14, weight: .semibold)
                            .foregroundStyle(KakitoriTheme.ink)
                            .lineLimit(1)
                        Text("\(cardCount) cards")
                            .font(.caption2)
                            .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                    }

                    Spacer(minLength: 8)

                    VStack(spacing: 0) {
                        Text("\(proficiencyPercentage)%")
                            .kakitoriFont(size: 13, weight: .bold)
                            .foregroundStyle(KakitoriTheme.accent)
                    }
                    .frame(width: 40, height: 40)
                    .background(KakitoriTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if isAllCaughtUp {
                    Text("All caught up")
                        .font(.caption)
                        .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                } else {
                    HStack(spacing: 8) {
                        chipView(
                            count: newCount,
                            label: "new",
                            background: KakitoriTheme.chipNewBackground,
                            foreground: KakitoriTheme.chipNewForeground
                        )
                        chipView(
                            count: learningCount,
                            label: "learning",
                            background: KakitoriTheme.chipLearnBackground,
                            foreground: KakitoriTheme.chipLearnForeground
                        )
                        chipView(
                            count: dueCount,
                            label: "due",
                            background: KakitoriTheme.chipDueBackground,
                            foreground: KakitoriTheme.chipDueForeground
                        )
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(KakitoriTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(KakitoriTheme.boxLine, lineWidth: 1)
            )
            .contentShape(Rectangle())
        })
        .accessibilityIdentifier("deck-row-\(deck.sourceDeckName.lowercased())")
    }

    private var representativeGlyph: String {
        let scripts = Set(deck.sections.flatMap(\.notes).filter { !$0.isDeleted }.map(\.script))
        if scripts == [.hiragana] {
            return "あ"
        }
        if scripts == [.katakana] {
            return "ア"
        }
        return "語"
    }

    private var regularCard: some View {
        Button(action: { onStudy(deck) }, label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.jpTitle ?? deck.name)
                            .font(KakitoriTheme.japaneseDisplayFont(size: 32))
                            .foregroundStyle(KakitoriTheme.ink)
                            .lineLimit(1)

                        Text(deck.name)
                            .kakitoriFont(size: 15, weight: .semibold)
                            .foregroundStyle(KakitoriTheme.ink)
                            .lineLimit(1)

                        Text("\(cardCount) cards")
                            .font(.caption)
                            .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 4) {
                        Text("\(proficiencyPercentage)%")
                            .kakitoriFont(size: 16, weight: .semibold)
                            .foregroundStyle(KakitoriTheme.paper)
                        Text("Mastery")
                            .font(.caption2)
                            .foregroundStyle(KakitoriTheme.paper.opacity(0.8))
                    }
                    .frame(width: 60)
                    .padding(8)
                    .background(KakitoriTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if isAllCaughtUp {
                    Text("All caught up")
                        .font(.caption)
                        .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                } else {
                    HStack(spacing: 8) {
                        chipView(
                            count: newCount,
                            label: "new",
                            background: KakitoriTheme.chipNewBackground,
                            foreground: KakitoriTheme.chipNewForeground
                        )
                        chipView(
                            count: learningCount,
                            label: "learning",
                            background: KakitoriTheme.chipLearnBackground,
                            foreground: KakitoriTheme.chipLearnForeground
                        )
                        chipView(
                            count: dueCount,
                            label: "due",
                            background: KakitoriTheme.chipDueBackground,
                            foreground: KakitoriTheme.chipDueForeground
                        )
                        Spacer()
                    }
                }

                HStack {
                    Spacer()
                    Text("Study →")
                        .kakitoriFont(size: 15, weight: .semibold)
                        .foregroundStyle(KakitoriTheme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(KakitoriTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(KakitoriTheme.boxLine, lineWidth: 1)
            )
        })
        .accessibilityIdentifier("deck-row-\(deck.sourceDeckName.lowercased())")
    }

    private func chipView(count: Int, label: String, background: Color, foreground: Color) -> some View {
        Text("\(count) \(label)")
            .font(.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cardCount: Int {
        var count = 0
        for section in deck.sections {
            for note in section.notes where !note.isDeleted {
                count += 1
            }
        }
        return count
    }

    private var proficiencyPercentage: Int {
        let nonDeletedNotes = deck.sections.flatMap(\.notes).filter { !$0.isDeleted }
        guard !nonDeletedNotes.isEmpty else { return 0 }

        let mature = nonDeletedNotes.count(where: { note in
            guard let schedule = note.schedule else { return false }
            return schedule.intervalDays >= 21
        })

        return Int(Double(mature) / Double(nonDeletedNotes.count) * 100)
    }

    var isAllCaughtUp: Bool {
        allowance.isAllCaughtUp
    }

    private var allowance: DailyAllowance {
        DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: endOfToday,
            newPerDay: settings.newCardsPerDay,
            maxReviewsPerDay: settings.maxReviewsPerDay,
            newIntroducedToday: newIntroducedToday,
            reviewsDoneToday: reviewsDoneToday
        )
    }

    private var newCount: Int {
        allowance.newCount
    }

    private var learningCount: Int {
        allowance.learnCount
    }

    private var dueCount: Int {
        allowance.dueCount
    }
}
