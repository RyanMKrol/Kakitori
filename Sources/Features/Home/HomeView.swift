import SwiftData
import SwiftUI

struct HomeView: View {
    @Query private var decks: [Deck]

    var body: some View {
        ZStack {
            KakitoriTheme.paper.ignoresSafeArea()

            VStack(spacing: 24) {
                header
                StatsRowView()

                if decks.isEmpty {
                    emptyState
                } else {
                    deckList
                }
            }
            .padding()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(KakitoriTheme.accent)
                    .frame(width: 44, height: 44)
                Text("書")
                    .font(KakitoriTheme.japaneseDisplayFont(size: 28))
                    .foregroundStyle(KakitoriTheme.paper)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Kakitori")
                    .font(.title2.bold())
                    .foregroundStyle(KakitoriTheme.ink)
                Text("Write your Japanese, card by card")
                    .font(.subheadline)
                    .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
            }

            Spacer()
        }
        .accessibilityIdentifier("home-header")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("書")
                .font(KakitoriTheme.japaneseDisplayFont(size: 64))
                .foregroundStyle(KakitoriTheme.inkFaint)
            Text("Import a deck to start writing")
                .font(.body)
                .foregroundStyle(KakitoriTheme.ink)
            Spacer()
        }
        .accessibilityIdentifier("home-empty-state")
    }

    private var deckList: some View {
        List(decks) { deck in
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.jpTitle ?? deck.name)
                    .font(KakitoriTheme.japaneseDisplayFont(size: 24))
                    .foregroundStyle(KakitoriTheme.ink)
                Text(deck.name)
                    .font(.caption)
                    .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
            }
        }
        .accessibilityIdentifier("home-deck-list")
    }
}
