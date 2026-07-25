import Foundation

/// The bounds on the two daily-limit settings, and the parsing that enforces them.
///
/// Kept out of the view so the rule is one thing in one place: whatever the user types, the value
/// that gets stored is inside the range. Out-of-range input is clamped rather than rejected —
/// silently dropping it reads as a broken text field.
enum DailyLimits {
    static let newCardsRange = 1 ... 999
    static let maxReviewsRange = 1 ... 999

    static func clampNewCardsPerDay(_ text: String) -> Int? {
        clamp(text, into: newCardsRange)
    }

    static func clampMaxReviewsPerDay(_ text: String) -> Int? {
        clamp(text, into: maxReviewsRange)
    }

    /// - Returns: the typed number pulled into `range`, or nil when there was no number to read —
    ///   an empty or junk field leaves the existing setting alone rather than inventing a value.
    private static func clamp(_ text: String, into range: ClosedRange<Int>) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)) else { return nil }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
