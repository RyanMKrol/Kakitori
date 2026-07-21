import Foundation
import SwiftData

/// Wipes all on-device study data so the app can be walked through from a clean-install state
/// (Settings → "Reset all data"). Deletes every deck/section/note/schedule and all daily stats,
/// and forgets the loaded-bundle version so the bundled decks re-import fresh on the next load.
/// The user's preferences (new-per-day, audio autoplay, show romaji, …) are intentionally kept.
@MainActor
enum AppDataReset {
    /// Reset on a DEDICATED context with autosave OFF, committing every deletion in ONE atomic save.
    /// This is what keeps the still-mounted Home `DeckCardView` list (a live `@Query` on the SAME
    /// store) from crashing: with the app's default autosaving context, the deletions commit
    /// incrementally and the Home query re-renders mid-wipe against a deck whose notes are already
    /// gone, trapping in SwiftData on `Note.script`. A single atomic save means Home only ever
    /// observes the before (all decks) and after (none) states — never a dangling intermediate.
    static func resetAll(container: ModelContainer, defaults: UserDefaults = .standard) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        // Delete whole decks (their cascade rule removes sections/notes/schedules together); then
        // mop up anything the cascade doesn't reach (section-less notes, orphaned schedules) and the
        // daily stats. Nothing is committed until the single save below.
        for deck in try context.fetch(FetchDescriptor<Deck>()) {
            context.delete(deck)
        }
        for note in try context.fetch(FetchDescriptor<Note>()) {
            context.delete(note)
        }
        for section in try context.fetch(FetchDescriptor<Section>()) {
            context.delete(section)
        }
        for schedule in try context.fetch(FetchDescriptor<CardSchedule>()) {
            context.delete(schedule)
        }
        for stats in try context.fetch(FetchDescriptor<DailyStats>()) {
            context.delete(stats)
        }
        try context.save()

        // Clear the on-disk imported media too. Deck UUIDs regenerate on the fresh re-import, so the
        // old Media/<deckID>/ trees would otherwise linger as orphans; removing the whole tree keeps
        // reset a true clean slate and lets the re-import repopulate it.
        try? FileManager.default.removeItem(at: BundledDeckLoader.mediaBaseURL().appendingPathComponent("Media"))

        BundledDeckLoader.resetLoadedVersion(defaults: defaults)
    }
}
