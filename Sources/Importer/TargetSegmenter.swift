import Foundation

enum SegmentedUnit: Equatable {
    case box(String)
    case inline(String)
}

enum TargetScript: String, Equatable {
    case hiragana, katakana, kanji, mixed
}

enum TargetSegmenter {
    private static let punctuation: Set<Character> = ["。", "、", "！", "？", "・", "ー"]

    static func segment(_ target: String) -> [SegmentedUnit] {
        var result: [SegmentedUnit] = []

        for char in target {
            if punctuation.contains(char) {
                result.append(.inline(String(char)))
            } else if char.isWhitespace || char.isNewline {
                continue
            } else {
                result.append(.box(String(char)))
            }
        }

        return result
    }

    static func classify(_ target: String) -> TargetScript {
        let units = segment(target)

        let boxChars = units.compactMap { unit in
            if case let .box(str) = unit {
                return str
            }
            return nil
        }

        if boxChars.isEmpty {
            return .mixed
        }

        var detectedScripts = Set<TargetScript>()

        for boxStr in boxChars {
            for scalar in boxStr.unicodeScalars {
                let value = scalar.value

                if value >= 0x3040, value <= 0x309F {
                    detectedScripts.insert(.hiragana)
                } else if value >= 0x30A0, value <= 0x30FF {
                    detectedScripts.insert(.katakana)
                } else if value >= 0x4E00, value <= 0x9FFF {
                    detectedScripts.insert(.kanji)
                } else {
                    detectedScripts.insert(.mixed)
                }
            }
        }

        if detectedScripts.count == 1, let script = detectedScripts.first, script != .mixed {
            return script
        }

        return .mixed
    }
}
