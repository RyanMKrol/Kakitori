import Foundation

enum ModeAvailability {
    // Note: PracticeMode is defined in Sources/Features/DeckSetup/DeckSetupSheet.swift
    // and Script is defined in Sources/Models/Note.swift. Both are imported via the Kakitori
    // module target.

    /// Returns the available practice modes for a deck based on the scripts it contains.
    ///
    /// - Kana-only decks (hiragana, katakana, or both): Trace, Listen & Write, Recall, Mixed.
    /// - Kanji or mixed-script decks: Trace, Listen & Write, Translate & Write, Recall, Mixed.
    static func deckModes(scripts: Set<Script>) -> [PracticeMode] {
        guard !scripts.isEmpty else { return [] }

        var modes: [PracticeMode] = [.trace, .listen]

        if scripts.contains(.kanji) || scripts.contains(.mixed) {
            modes.append(.translate)
        }

        modes.append(.recall)
        modes.append(.mixed)

        return modes
    }

    /// Determines whether a card qualifies for a given practice mode.
    ///
    /// - `.listen`: Requires audio or TTS availability (per docs/04-content-and-data.md §1.1 and §4).
    /// - `.translate`: Requires a non-empty (after trimming), non-nil English gloss.
    /// - `.trace`, `.recall`, `.mixed`: Always qualify.
    static func cardQualifies(
        _ mode: PracticeMode,
        hasAudio: Bool,
        ttsAvailable: Bool,
        english: String?
    ) -> Bool {
        switch mode {
        case .listen:
            return hasAudio || ttsAvailable
        case .translate:
            guard let english else { return false }
            return !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .trace, .recall, .mixed:
            return true
        }
    }
}
