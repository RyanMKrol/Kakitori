import SwiftData
import SwiftUI

struct HomeView: View {
    @Query private var decks: [Deck]
    let now: Date = AppClock.system.now()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                KakitoriTheme.paper.ignoresSafeArea()

                VStack(spacing: 24) {
                    header
                    StatsRowView()

                    if decks.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 16) {
                            TodayBannerView(now: now)
                            deckList
                        }
                    }
                }
                .padding()
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "settings" {
                    SettingsView()
                }
            }
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

            Button(action: { navigationPath.append("settings") }, label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(KakitoriTheme.ink)
                    .frame(width: 44, height: 44)
            })
            .accessibilityIdentifier("settings-button")
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
            Button(action: {}, label: {
                Text("Import deck")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(KakitoriTheme.paper)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(KakitoriTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            })
            .accessibilityIdentifier("import-button-empty")
            Spacer()
        }
        .accessibilityIdentifier("home-empty-state")
    }

    private var deckList: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(decks) { deck in
                DeckCardView(deck: deck, now: now, onStudy: { _ in })
            }
        }
        .accessibilityIdentifier("home-deck-list")
    }
}
