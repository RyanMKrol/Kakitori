import SwiftUI
import UIKit

/// The candidate typefaces for the glyphs the user copies when practising.
///
/// This matters more here than in most apps: the glyph on the answer (and in the trace guides) is
/// the MODEL being copied, so its shapes are what the user's hand learns. A 明朝 face carries the
/// flares and stroke-contrast of a brush, which is decoration a person writing with a pen doesn't
/// reproduce — hence the comparison.
///
/// The distinction that decides this isn't weight or flourish, it's WHICH FORM the face draws.
/// き and さ are written with the bottom curve as a separate stroke — pen lifted, visible gap — and
/// り with its two strokes apart. Every Japanese face iOS ships (Hiragino Sans, Maru Gothic,
/// Mincho) draws the printed forms instead, with those strokes joined on. Copying those teaches the
/// wrong hand. 教科書体, the class of face Japanese schools use precisely because it matches
/// handwriting, isn't on iOS at any weight, so the handwriting faces here are bundled with the app.
///
/// `resolvedFontName` falls back and `isAvailable` reports whether a choice is the real thing or a
/// substitute — a bundled font that failed to register would otherwise silently render as the
/// system face and look like a legitimate option.
enum PracticeFont: String, CaseIterable, Identifiable {
    /// System sans, the current front-runner. Even strokes, no flourishes — but PRINTED forms, so
    /// き and さ come out joined. Kept as the reference to judge the others against.
    case gothic

    /// Bundled. A pen/pencil face from Fontworks with 楷書 bones, close to what 教科書体 is for:
    /// handwritten forms, moderate stroke variation, made to be read and copied.
    case kleeOne

    /// Bundled. Handwriting proper — looser and more personal than Klee, same correct forms.
    case zenKurenaido

    var id: String {
        rawValue
    }

    /// Shown next to each sample so a choice can be named.
    var displayName: String {
        switch self {
        case .gothic: "Gothic"
        case .kleeOne: "Klee One"
        case .zenKurenaido: "Zen Kurenaido"
        }
    }

    /// One line on what the face does to the characters being copied.
    var summary: String {
        switch self {
        case .gothic: "Printed forms — き joins up"
        case .kleeOne: "Pen forms — き keeps its gap"
        case .zenKurenaido: "Handwriting — き keeps its gap"
        }
    }

    /// Whether this face draws the separated strokes a person writing by hand actually makes.
    var usesHandwrittenForms: Bool {
        switch self {
        case .gothic: false
        case .kleeOne, .zenKurenaido: true
        }
    }

    /// PostScript names in order of preference. The first that exists on this device wins.
    private var candidates: (regular: [String], bold: [String]) {
        switch self {
        case .gothic:
            (["HiraginoSans-W3", "HiraKakuProN-W3"], ["HiraginoSans-W6", "HiraKakuProN-W6"])
        case .kleeOne:
            // Bundled at ONE weight, SemiBold — Klee's Regular is far lighter than the system
            // gothic it's being judged against, and a weight difference that big reads as a
            // quality difference. Bold maps to the same file rather than a heavier system face:
            // substituting Hiragino would swap the letterforms back to printed ones, which is the
            // exact thing this option exists to avoid.
            (["KleeOne-SemiBold"], ["KleeOne-SemiBold"])
        case .zenKurenaido:
            // Ships in one weight only, so it renders lighter than the other two by design.
            (["ZenKurenaido-Regular"], ["ZenKurenaido-Regular"])
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
