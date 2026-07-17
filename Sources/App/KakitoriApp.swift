import SwiftData
import SwiftUI

@main
struct KakitoriApp: App {
    let container: ModelContainer = Self.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
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
