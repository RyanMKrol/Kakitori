import Foundation
import SwiftData

/// Loads the hand-bundled `.apkg` decks (BundledDecks/*.apkg, shipped as app resources) into the
/// store on launch. This is how content gets in for now — the in-app package importer is deferred, so
/// the decks are baked into the app and always present with no onboarding.
///
/// Idempotent and cheap on steady state: gated by a bundle-version flag so the one-time import + media
/// copy runs only when the shipped deck set changes. Reuses the full `ApkgImporter` pipeline (parse →
/// upsert → media copy), whose re-import logic is itself idempotent as a second line of defence.
enum BundledDeckLoader {
    /// Bump when the bundled `.apkg` set changes so existing installs re-import on their next launch.
    static let bundleVersion = 2
    private static let versionKey = "loadedBundledDecksVersion"

    /// Resource base-names (without extension) of the shipped decks, in display order. The single
    /// first-party "Foundations" source is SPLIT on load into separate Hiragana / Katakana / Kanji
    /// decks (see `sectionTitles` + ApkgImporter.importDeckSplitBySection) — it is used as a content
    /// pool, never surfaced directly.
    static let deckResourceNames = ["Foundations"]

    /// The `.apkg` top-level deck name the Foundations source splits under ("Kakitori Foundations::…").
    static let rootDeckName = "Kakitori Foundations"

    /// Friendly display name + JP title for each section the Foundations source splits into, keyed by
    /// the importer's section name (the `.apkg` subdeck under "Kakitori Foundations::…").
    static let sectionTitles: [String: (name: String, jpTitle: String?)] = [
        "Hiragana": ("Hiragana", "ひらがな"),
        "Katakana": ("Katakana", "カタカナ"),
        "Kanji": ("Kanji", "漢字"),
    ]

    /// The `sourceDeckName`s the current bundle produces — every split deck's `"<root>::<section>"`.
    /// Any on-disk `Deck` outside this set is retired content to be pruned. Computed without parsing
    /// the `.apkg`, so the reconcile-prune can run cheaply on every launch (not just a version bump).
    static var expectedSourceNames: Set<String> {
        Set(sectionTitles.keys.map { "\(rootDeckName)::\($0)" })
    }

    /// Where imported deck audio/media is copied (matches the rest of the app).
    static func mediaBaseURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kakitori/Media")
    }

    static func bundledDeckURLs(in bundle: Bundle = .main) -> [URL] {
        deckResourceNames.compactMap { name in
            // Tolerate either a flattened resource or a "BundledDecks" folder reference.
            bundle.url(forResource: name, withExtension: "apkg")
                ?? bundle.url(forResource: name, withExtension: "apkg", subdirectory: "BundledDecks")
        }
    }

    /// Whether the current bundle version has already been imported (nothing to do).
    static func isUpToDate(defaults: UserDefaults = .standard) -> Bool {
        defaults.integer(forKey: versionKey) == bundleVersion
    }

    /// Forget that the bundled decks were loaded, so the next load re-imports them from scratch
    /// (used by the Settings "reset all data" action to restore a clean-install state).
    static func resetLoadedVersion(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: versionKey)
    }

    /// Import every bundled deck into `container`. Idempotent per deck. Returns the first error
    /// encountered (nil on success); records the loaded version only when every deck succeeded.
    @discardableResult
    static func load(
        container: ModelContainer,
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) async -> ImporterError? {
        let urls = bundledDeckURLs(in: bundle)
        guard !urls.isEmpty else { return nil }

        let importer = ApkgImporter(container: container, mediaBaseURL: mediaBaseURL())
        var firstError: ImporterError?
        for url in urls {
            do {
                // Split the source deck's sections into separate Hiragana/Katakana/Kanji decks.
                try await importer.importDeckSplitBySection(from: url, titles: sectionTitles)
            } catch let error as ImporterError {
                firstError = firstError ?? error
            } catch {
                firstError = firstError ?? .badZip
            }
        }

        if firstError == nil {
            pruneRetiredDecks(container: container, keeping: expectedSourceNames)
            defaults.set(bundleVersion, forKey: versionKey)
        }
        // (`expectedSourceNames` is the computed static above — no need to derive it from a parse.)
        return firstError
    }

    /// Delete any on-disk `Deck` no longer produced by the current bundle (e.g. the retired Tofugu
    /// decks left behind by an install that upgraded past the Foundations split). Only decks whose
    /// `sourceDeckName` is outside `expectedSourceNames` are touched; deleting a `Deck` cascades to its
    /// `Section`s and `Note`s (and, via `Note.schedule`'s cascade rule, their `CardSchedule`s) so no
    /// orphaned rows are left behind.
    static func pruneRetiredDecks(container: ModelContainer, keeping expectedSourceNames: Set<String>) {
        let context = ModelContext(container)
        guard let decks = try? context.fetch(FetchDescriptor<Deck>()) else { return }

        let staleDecks = decks.filter { !expectedSourceNames.contains($0.sourceDeckName) }
        guard !staleDecks.isEmpty else { return }

        // Sectionless notes are linked directly via `Note.deck` (not through `Section`), so the
        // Deck -> Section -> Note cascade wouldn't reach them; delete those explicitly first.
        if let sectionlessNotes = try? context.fetch(FetchDescriptor<Note>()) {
            for note in sectionlessNotes where note.section == nil {
                if staleDecks.contains(where: { $0 === note.deck }) {
                    context.delete(note)
                }
            }
        }

        for deck in staleDecks {
            context.delete(deck)
        }

        try? context.save()
    }
}

/// Observable launch-time state for the bundled-deck load, so the Home screen can show a "preparing"
/// state on first launch and an error if it fails, instead of the old import-onboarding empty state.
@MainActor
@Observable
final class DeckLoadModel {
    enum Phase: Equatable {
        case idle
        case loading
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private var didRun = false

    /// Run once per app launch. No-op (stays `.idle`) if the bundled decks are already loaded.
    func runIfNeeded(container: ModelContainer) async {
        guard !didRun else { return }
        didRun = true

        // Reconcile the on-disk deck set against the current bundle on EVERY launch, even when the
        // import is up to date. An install that loaded an earlier bundle version before the prune
        // existed (or before the deck set changed) would otherwise keep retired decks forever, since
        // the prune used to run only inside the version-gated load(). This is cheap (one fetch + a
        // filtered delete) and self-healing.
        BundledDeckLoader.pruneRetiredDecks(container: container, keeping: BundledDeckLoader.expectedSourceNames)

        guard !BundledDeckLoader.isUpToDate() else {
            phase = .idle
            return
        }

        phase = .loading
        if let error = await BundledDeckLoader.load(container: container) {
            phase = .failed(error.userMessage)
        } else {
            phase = .idle
        }
    }

    /// Allow a manual retry after a failure.
    func retry(container: ModelContainer) async {
        didRun = false
        await runIfNeeded(container: container)
    }
}
