import Foundation
import SwiftData

enum Script: String, Codable {
    case hiragana
    case katakana
    case kanji
    case mixed
}

@Model
final class Note {
    var id: UUID
    var target: String
    var pronunciation: String?
    var english: String?
    var category: String?
    var hint: String?
    var audioFilename: String?
    var script: Script
    var units: [String]
    var isSoftDeleted: Bool
    var section: Section?
    /// Cascade so a deleted note never leaves behind an orphaned schedule row (SwiftData's default
    /// nullify would just clear `CardSchedule.note` and strand the schedule in the store).
    @Relationship(deleteRule: .cascade, inverse: \CardSchedule.note) var schedule: CardSchedule?
    /// Direct owning-deck link so re-import can find sectionless notes too, not just via `section`.
    var deck: Deck?

    /// Read-only alias kept for out-of-scope call sites; the writable flag is `isSoftDeleted` (see above).
    var isDeleted: Bool {
        isSoftDeleted
    }

    init(
        id: UUID = UUID(),
        target: String,
        pronunciation: String? = nil,
        english: String? = nil,
        category: String? = nil,
        hint: String? = nil,
        audioFilename: String? = nil,
        script: Script,
        units: [String] = [],
        isSoftDeleted: Bool = false,
        section: Section? = nil,
        schedule: CardSchedule? = nil,
        deck: Deck? = nil
    ) {
        self.id = id
        self.target = target
        self.pronunciation = pronunciation
        self.english = english
        self.category = category
        self.hint = hint
        self.audioFilename = audioFilename
        self.script = script
        self.units = units
        self.isSoftDeleted = isSoftDeleted
        self.section = section
        self.schedule = schedule
        self.deck = deck
    }
}
