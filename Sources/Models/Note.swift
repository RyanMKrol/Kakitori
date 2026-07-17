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
    var isDeleted: Bool
    var section: Section?

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
        isDeleted: Bool = false,
        section: Section? = nil
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
        self.isDeleted = isDeleted
        self.section = section
    }
}
