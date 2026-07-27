import SwiftUI
import UIKit

/// The candidate typefaces for the glyphs the user copies when practising.
///
/// This matters more here than in most apps: the glyph on the answer (and in the trace guides) is
/// the MODEL being copied, so its shapes are what the user's hand learns. A 明朝 face carries the
/// flares and stroke-contrast of a brush, which is decoration a person writing with a pen doesn't
/// reproduce — hence the comparison.
///
/// Only Hiragino ships on every iOS install. The textbook faces you'd actually want for
/// handwriting — 教科書体 proper, or Klee, or Toppan Bunkyu — are not on the simulator runtime and
/// can't be relied on, so `resolvedFontName` falls back and `isAvailable` says whether the choice
/// is the real thing or a substitute. Without that, two options rendering the same fallback would
/// look identical with no explanation.
enum PracticeFont: String, CaseIterable, Identifiable {
    /// Uniform-width sans. No brush contrast at all — the plain skeleton of each character, which
    /// is the closest of the three to what a pen actually produces.
    case gothic

    /// Rounded terminals. Same skeleton as the gothic, softer ends — reads as handwritten without
    /// the stroke-contrast of a brush face.
    case maruGothic

    /// The current face: 明朝, a serif whose weight varies through the stroke and whose ends flare.
    /// Kept in the comparison as the control — it's what the app looks like today.
    case mincho

    var id: String {
        rawValue
    }

    /// Shown next to each sample so a choice can be named.
    var displayName: String {
        switch self {
        case .gothic: "Gothic"
        case .maruGothic: "Rounded"
        case .mincho: "Mincho (current)"
        }
    }

    /// One line on what the face does to the characters being copied.
    var summary: String {
        switch self {
        case .gothic: "Even strokes, no flourishes"
        case .maruGothic: "Even strokes, softened ends"
        case .mincho: "Brush-style contrast and flared ends"
        }
    }

    /// PostScript names in order of preference. The first that exists on this device wins.
    private var candidates: (regular: [String], bold: [String]) {
        switch self {
        case .gothic:
            (["HiraginoSans-W3", "HiraKakuProN-W3"], ["HiraginoSans-W6", "HiraKakuProN-W6"])
        case .maruGothic:
            // Maru Gothic ships in a single W4 weight, so bold falls back to the gothic's W6
            // rather than letting SwiftUI synthesise a smeared fake bold.
            (["HiraMaruProN-W4"], ["HiraMaruProN-W4", "HiraginoSans-W6"])
        case .mincho:
            (["HiraMinProN-W3"], ["HiraMinProN-W6"])
        }
    }

    /// The name that will actually be used, or nil if none of the candidates exist here.
    func resolvedFontName(bold: Bool) -> String? {
        let names = bold ? candidates.bold : candidates.regular
        return names.first { UIFont(name: $0, size: 12) != nil }
    }

    var isAvailable: Bool {
        resolvedFontName(bold: false) != nil
    }

    /// Scales with Dynamic Type.
    func font(size: CGFloat, bold: Bool = false) -> Font {
        guard let name = resolvedFontName(bold: bold) else {
            return .system(size: size, weight: bold ? .bold : .regular)
        }
        return .custom(name, size: size)
    }

    /// Fixed size regardless of Dynamic Type — for the glyphs being written, which are content
    /// rather than chrome.
    func fixedFont(size: CGFloat, bold: Bool = false) -> Font {
        guard let name = resolvedFontName(bold: bold) else {
            return .system(size: size, weight: bold ? .bold : .regular)
        }
        return .custom(name, fixedSize: size)
    }
}
