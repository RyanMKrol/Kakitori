import SwiftUI
import UIKit

/// The typeface every Japanese glyph in the app is drawn in: **Klee One**, bundled with the app.
///
/// Chosen for one reason. き and さ are written with the bottom curve as a separate stroke — pen
/// lifted, visible gap — and り with its two strokes apart. Every Japanese face iOS ships (Hiragino
/// Sans, Maru Gothic, Mincho) draws the printed forms instead, with those strokes joined on, and so
/// does BIZ UDGothic. Klee draws the handwritten forms. That matters more here than in most apps:
/// the glyph on screen is the model being copied, so its shapes are what the user's hand learns.
///
/// 教科書体 — the class of face Japanese schools use for exactly this reason — isn't on iOS at any
/// weight, and the licensable ones can't be redistributed. Klee One (Fontworks, SIL OFL 1.1) is a
/// pen face with 楷書 bones and is the closest freely licensable equivalent.
enum PracticeFont {
    /// PostScript names in preference order. Hiragino trails as a safety net: if the bundled font
    /// ever fails to register, glyphs still draw — in the wrong (printed) forms, which is bad but
    /// better than a blank screen. `isBundledFontRegistered` is what catches that case.
    private static let regularCandidates = ["KleeOne-Regular", "HiraginoSans-W3"]
    private static let boldCandidates = ["KleeOne-SemiBold", "HiraginoSans-W6"]

    static func resolvedFontName(bold: Bool) -> String? {
        let names = bold ? boldCandidates : regularCandidates
        return names.first { UIFont(name: $0, size: 12) != nil }
    }

    /// False when the app is falling back to a system face — the letterforms are wrong for
    /// practice, and nothing on screen would otherwise say so.
    static var isBundledFontRegistered: Bool {
        resolvedFontName(bold: false)?.hasPrefix("KleeOne") == true
            && resolvedFontName(bold: true)?.hasPrefix("KleeOne") == true
    }

    /// Scales with Dynamic Type.
    static func font(size: CGFloat, bold: Bool = false) -> Font {
        guard let name = resolvedFontName(bold: bold) else {
            return .system(size: size, weight: bold ? .bold : .regular)
        }
        return .custom(name, size: size)
    }

    /// Fixed size regardless of Dynamic Type — for the glyphs being written, which are content
    /// rather than chrome.
    static func fixedFont(size: CGFloat, bold: Bool = false) -> Font {
        guard let name = resolvedFontName(bold: bold) else {
            return .system(size: size, weight: bold ? .bold : .regular)
        }
        return .custom(name, fixedSize: size)
    }
}
