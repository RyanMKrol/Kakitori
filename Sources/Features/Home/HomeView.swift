import SwiftData
import SwiftUI

struct HomeView: View {
    @Query private var decks: [Deck]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(DeckLoadModel.self) private var deckLoad
    let now: Date = AppClock.system.now()
    @State private var navigationPath = NavigationPath()
    @State private var setupDeck: Deck?
    @State private var activeSession: SessionViewModel?
    @State private var activeSessionDeck: Deck?
    @State private var deckPendingRestudy: Deck?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                KakitoriTheme.paper.ignoresSafeArea()

                VStack(spacing: 24) {
                    header
                    StatsRowView()

                    if !decks.isEmpty {
                        VStack(spacing: 16) {
                            TodayBannerView(now: now)
                            deckList
                        }
                    } else if case let .failed(message) = deckLoad.phase {
                        loadFailedState(message)
                    } else {
                        loadingState
                    }
                }
                .padding()
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "settings" {
                    SettingsView()
                }
            }
            .sheet(isPresented: setupSheetBinding) {
                if let setupDeck {
                    let scripts = Set(setupDeck.sections.flatMap(\.notes).filter { !$0.isDeleted }.map(\.script))
                    let availableModes = ModeAvailability.deckModes(scripts: scripts)
                    DeckSetupSheet(
                        jpTitle: setupDeck.jpTitle ?? setupDeck.name,
                        enTitle: setupDeck.name,
                        dueCount: dueCount(for: setupDeck),
                        availableModes: availableModes,
                        onStart: { mode in startSession(deck: setupDeck, mode: mode) },
                        onClose: { self.setupDeck = nil }
                    )
                    .presentationDetents(horizontalSizeClass == .compact ? [.medium] : [.large])
                }
            }
            .fullScreenCover(
                isPresented: sessionCoverBinding,
                onDismiss: {
                    if let deckPendingRestudy {
                        setupDeck = deckPendingRestudy
                        self.deckPendingRestudy = nil
                    }
                },
                content: { sessionCoverContent }
            )
        }
    }

    private var setupSheetBinding: Binding<Bool> {
        Binding(get: { setupDeck != nil }, set: { if !$0 { setupDeck = nil } })
    }

    private var sessionCoverBinding: Binding<Bool> {
        Binding(get: { activeSession != nil }, set: { if !$0 { activeSession = nil } })
    }

    @ViewBuilder
    private var sessionCoverContent: some View {
        if let activeSession {
            if activeSession.phase == .finished, let summary = activeSession.summary {
                SummaryView(
                    cardsWritten: summary.cardsWritten,
                    minutes: summary.seconds / 60,
                    againCount: summary.gradeCounts[.again] ?? 0,
                    hardCount: summary.gradeCounts[.hard] ?? 0,
                    goodCount: summary.gradeCounts[.good] ?? 0,
                    easyCount: summary.gradeCounts[.easy] ?? 0,
                    streakDays: currentStreak,
                    onBackToDecks: {
                        self.activeSession = nil
                        activeSessionDeck = nil
                    },
                    onStudyAnother: {
                        deckPendingRestudy = activeSessionDeck
                        self.activeSession = nil
                        activeSessionDeck = nil
                    }
                )
            } else {
                SessionView(viewModel: activeSession, onClose: {
                    activeSession.close()
                    self.activeSession = nil
                    activeSessionDeck = nil
                })
            }
        }
    }

    private var currentStreak: Int {
        let allStats = (try? modelContext.fetch(FetchDescriptor<DailyStats>())) ?? []
        let activeDays = Set(allStats.map(\.day))
        return DailyStats.currentStreak(activeDays: activeDays, now: AppClock.system.now(), clock: .system)
    }

    private func dueCount(for deck: Deck) -> Int {
        DailyAllowance.forDeck(
            deck,
            now: now,
            endOfToday: AppClock.system.endOfToday(after: now),
            newPerDay: AppSettings().newCardsPerDay,
            maxReviewsPerDay: AppSettings().maxReviewsPerDay,
            newIntroducedToday: todayStats?.newIntroduced ?? 0,
            reviewsDoneToday: todayStats?.reviewsDone ?? 0
        ).total
    }

    private var todayStats: DailyStats? {
        let today = AppClock.system.adjustedDay(for: now)
        var descriptor = FetchDescriptor<DailyStats>(predicate: #Predicate { $0.day == today })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func startSession(deck: Deck, mode: PracticeMode) {
        setupDeck = nil
        activeSessionDeck = deck
        activeSession = SessionViewModel(
            deck: deck,
            mode: mode,
            modelContext: modelContext,
            clock: .system,
            seed: UInt64.random(in: UInt64.min ... UInt64.max)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(KakitoriTheme.accent)
                    .frame(width: 44, height: 44)
                Text("書")
                    .font(KakitoriTheme.japaneseDisplayFontFixed(size: 28))
                    .foregroundStyle(KakitoriTheme.paper)
                    .accessibilityHidden(true)
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

    /// Shown on first launch while the bundled decks are being imported (one-time).
    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("書")
                .font(KakitoriTheme.japaneseDisplayFontFixed(size: 64))
                .foregroundStyle(KakitoriTheme.inkFaint)
                .accessibilityHidden(true)
            ProgressView()
                .tint(KakitoriTheme.accent)
            Text("Preparing your decks…")
                .font(.body)
                .foregroundStyle(KakitoriTheme.ink)
            Spacer()
        }
        .accessibilityIdentifier("home-loading-state")
    }

    private func loadFailedState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("書")
                .font(KakitoriTheme.japaneseDisplayFontFixed(size: 64))
                .foregroundStyle(KakitoriTheme.inkFaint)
                .accessibilityHidden(true)
            Text("Couldn't load your decks")
                .font(.body.bold())
                .foregroundStyle(KakitoriTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                .multilineTextAlignment(.center)
            Button(action: { Task { await deckLoad.retry(container: modelContext.container) } }, label: {
                Text("Try again")
                    .kakitoriFont(size: 16, weight: .semibold)
                    .foregroundStyle(KakitoriTheme.paper)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(KakitoriTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            })
            .accessibilityIdentifier("deck-load-retry")
            Spacer()
        }
        .accessibilityIdentifier("home-load-failed-state")
    }

    @ViewBuilder
    private var deckList: some View {
        if horizontalSizeClass == .compact {
            VStack(spacing: 12) {
                ForEach(decks) { deck in
                    DeckCardView(
                        deck: deck,
                        now: now,
                        newIntroducedToday: todayStats?.newIntroduced ?? 0,
                        reviewsDoneToday: todayStats?.reviewsDone ?? 0,
                        onStudy: { setupDeck = $0 }
                    )
                }
            }
            .accessibilityIdentifier("home-deck-list")
        } else {
            let columns = [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
            ]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(decks) { deck in
                    DeckCardView(
                        deck: deck,
                        now: now,
                        newIntroducedToday: todayStats?.newIntroduced ?? 0,
                        reviewsDoneToday: todayStats?.reviewsDone ?? 0,
                        onStudy: { setupDeck = $0 }
                    )
                }
            }
            .accessibilityIdentifier("home-deck-list")
        }
    }
}
