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
    static func map(_ note: AnkiNote, using model: AnkiModel) throws -> MappedNote {
        let fieldMap = zip(model.fieldNames, note.fields)
            .reduce(into: [String: String]()) { dict, pair in
                dict[pair.0] = pair.1
            }

        let cleanedTarget = cleanHTML(fieldMap["Target"] ?? "")
        guard !cleanedTarget.isEmpty else {
            throw NoteFieldMapperError.emptyTarget(noteID: note.id)
        }

        let audioField = fieldMap["Audio"] ?? ""
        let audioFilename = extractAudioFilename(from: audioField)

        return MappedNote(
            ankiGUID: note.guid,
            ankiDeckID: note.deckID,
            target: cleanedTarget,
            pronunciation: optionalCleanedField(fieldMap["Pronunciation"]),
            english: optionalCleanedField(fieldMap["English"]),
            category: optionalCleanedField(fieldMap["Category"]),
            hint: optionalCleanedField(fieldMap["Hint"]),
            image: optionalCleanedField(fieldMap["Image"]),
            audioFilename: audioFilename
        )
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
