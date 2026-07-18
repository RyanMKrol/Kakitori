import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Query private var decks: [Deck]
    @Environment(\.modelContext) private var modelContext
    let now: Date = AppClock.system.now()
    @State private var navigationPath = NavigationPath()
    @State private var showFileImporter = false
    @State private var coordinator = ImportCoordinator.shared

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

                if case let .running(progress) = coordinator.state {
                    ProgressOverlay(progress: progress)
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "settings" {
                    SettingsView()
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: buildAllowedContentTypes(),
                onCompletion: handleFileSelection
            )
            .alert(
                "Import failed",
                isPresented: .constant(coordinator.state.isFailure),
                actions: {
                    Button("OK") {
                        coordinator.state = .idle
                    }
                },
                message: {
                    if case let .failed(message) = coordinator.state {
                        Text(message)
                    }
                }
            )
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

            Button(action: { showFileImporter = true }, label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundStyle(KakitoriTheme.ink)
                    .frame(width: 44, height: 44)
            })
            .accessibilityIdentifier("import-button")

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
            Button(action: { showFileImporter = true }, label: {
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

    private func buildAllowedContentTypes() -> [UTType] {
        var types: [UTType] = []
        if let apkgType = UTType(filenameExtension: "apkg") {
            types.append(apkgType)
        }
        types.append(.zip)
        types.append(.data)
        return types
    }

    private func handleFileSelection(result: Result<URL, any Error>) {
        switch result {
        case let .success(url):
            Task {
                let mediaBaseURL = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                )[0].appendingPathComponent("Kakitori/Media")

                let container = modelContext.container
                await coordinator.begin(url: url, modelContainer: container, mediaBaseURL: mediaBaseURL)
            }
        case .failure:
            break
        }
    }
}

struct ProgressOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .tint(KakitoriTheme.accent)
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(KakitoriTheme.ink)
            }
            .padding(24)
            .background(KakitoriTheme.paper)
            .cornerRadius(12)
            .frame(maxWidth: 200)
        }
    }
}
