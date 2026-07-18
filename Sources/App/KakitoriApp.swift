import SwiftData
import SwiftUI

@main
struct KakitoriApp: App {
    let container: ModelContainer = Self.makeModelContainer()

    init() {
        #if DEBUG
            DemoSeed.seedIfNeeded(context: container.mainContext, clock: .system)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
        }
        .modelContainer(container)
    }

    private func handleOpenURL(_ url: URL) {
        Task {
            let mediaBaseURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("Kakitori/Media")

            await ImportCoordinator.shared.begin(url: url, modelContainer: container, mediaBaseURL: mediaBaseURL)
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Deck.self,
            Section.self,
            Note.self,
            CardSchedule.self,
            DailyStats.self,
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
