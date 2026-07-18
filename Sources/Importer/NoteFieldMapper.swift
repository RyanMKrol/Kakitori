import Foundation

struct MappedNote: Equatable {
    let ankiGUID: String
    let ankiDeckID: Int64?
    let target: String
    let pronunciation: String?
    let english: String?
    let category: String?
    let hint: String?
    let image: String?
    let audioFilename: String?
}

enum NoteFieldMapperError: Error, Equatable {
    case emptyTarget(noteID: Int64)
}

enum NoteFieldMapper {
    // Ordered field-name aliases — the FIRST present field wins. "Target" (etc.) stays first so decks
    // from the companion anki-builder pipeline map exactly as before; the later aliases add support for
    // hand-bundled third-party decks (e.g. the Tofugu "Klee One" kana decks, whose notetype uses
    // Kana / Romaji / Mnemonic Text / Audio). Add a new alias here to teach the importer another deck.
    static let targetFieldAliases = ["Target", "Kana", "Characters", "Character", "Kanji", "Word", "Expression"]
    static let pronunciationFieldAliases = ["Pronunciation", "Romaji", "Reading", "Furigana"]
    static let englishFieldAliases = ["English", "Meaning", "Definition"]
    static let categoryFieldAliases = ["Category"]
    static let hintFieldAliases = ["Hint", "Mnemonic Text", "Mnemonic"]
    static let imageFieldAliases = ["Image", "Mnemonic Image"]
    static let audioFieldAliases = ["Audio", "Sound"]

    /// Whether a notetype's fields can supply a writing target — the gate for "is this deck importable".
    static func hasMappableTarget(_ fieldNames: [String]) -> Bool {
        let names = Set(fieldNames)
        return targetFieldAliases.contains(where: names.contains)
    }

    static func map(_ note: AnkiNote, using model: AnkiModel) throws -> MappedNote {
        let fieldMap = zip(model.fieldNames, note.fields)
            .reduce(into: [String: String]()) { dict, pair in
                dict[pair.0] = pair.1
            }

        let cleanedTarget = cleanHTML(firstPresent(targetFieldAliases, in: fieldMap) ?? "")
        guard !cleanedTarget.isEmpty else {
            throw NoteFieldMapperError.emptyTarget(noteID: note.id)
        }

        let audioField = firstPresent(audioFieldAliases, in: fieldMap) ?? ""
        let audioFilename = extractAudioFilename(from: audioField)

        return MappedNote(
            ankiGUID: note.guid,
            ankiDeckID: note.deckID,
            target: cleanedTarget,
            pronunciation: optionalCleanedField(firstPresent(pronunciationFieldAliases, in: fieldMap)),
            english: optionalCleanedField(firstPresent(englishFieldAliases, in: fieldMap)),
            category: optionalCleanedField(firstPresent(categoryFieldAliases, in: fieldMap)),
            hint: optionalCleanedField(firstPresent(hintFieldAliases, in: fieldMap)),
            image: optionalCleanedField(firstPresent(imageFieldAliases, in: fieldMap)),
            audioFilename: audioFilename
        )
    }

    /// The value of the first alias that is present as a field on this note (even if empty), preserving
    /// the original "use this field if it exists" semantics while allowing multiple accepted names.
    private static func firstPresent(_ aliases: [String], in fieldMap: [String: String]) -> String? {
        for alias in aliases {
            if let value = fieldMap[alias] {
                return value
            }
        }
        return nil
    }

    private static func optionalCleanedField(_ field: String?) -> String? {
        guard let field else { return nil }
        let cleaned = cleanHTML(field)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func cleanHTML(_ html: String) -> String {
        var result = html

        result = result
            .replacingOccurrences(of: "<br>", with: " ")
            .replacingOccurrences(of: "<br/>", with: " ")
            .replacingOccurrences(of: "<br />", with: " ")
            .replacingOccurrences(of: "</div>", with: " ")
            .replacingOccurrences(of: "</p>", with: " ")

        result = removeTagsWithRegex(result)

        result = result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    private static func removeTagsWithRegex(_ text: String) -> String {
        let tagPattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: tagPattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private static func extractAudioFilename(from audioField: String) -> String? {
        let soundPattern = #"\[sound:([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: soundPattern, options: []) else {
            return nil
        }
        let range = NSRange(audioField.startIndex..., in: audioField)
        guard let match = regex.firstMatch(in: audioField, options: [], range: range) else {
            return nil
        }
        guard let captureRange = Range(match.range(at: 1), in: audioField) else {
            return nil
        }
        return String(audioField[captureRange])
    }
}
