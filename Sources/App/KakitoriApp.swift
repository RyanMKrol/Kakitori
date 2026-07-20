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
        let schema = Schema(versionedSchema: KakitoriSchemaV2.self)
        do {
            return try ModelContainer(for: schema, migrationPlan: KakitoriMigrationPlan.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
