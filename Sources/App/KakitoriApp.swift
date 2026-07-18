import SwiftData
import SwiftUI

@main
struct KakitoriApp: App {
    let container: ModelContainer = Self.makeModelContainer()

    @State private var deckLoad = DeckLoadModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environment(deckLoad)
            .task {
                await deckLoad.runIfNeeded(container: container)
            }
        }
        .modelContainer(container)
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
