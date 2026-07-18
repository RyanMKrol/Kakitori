import SwiftUI
import UIKit

public enum KakitoriTheme {
    // MARK: - Palette

    private static let paperLight = UIColor(red: 250 / 255, green: 248 / 255, blue: 244 / 255, alpha: 1)
    private static let paperDark = UIColor(red: 23 / 255, green: 21 / 255, blue: 15 / 255, alpha: 1)
    private static let inkLight = UIColor(red: 26 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1)
    private static let inkDark = UIColor(red: 240 / 255, green: 237 / 255, blue: 230 / 255, alpha: 1)
    private static let surfaceDark = UIColor(red: 33 / 255, green: 30 / 255, blue: 23 / 255, alpha: 1)

    public static let paper = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? paperDark : paperLight
    })
    public static let inkUIColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? inkDark : inkLight
    }

    public static let ink = Color(uiColor: inkUIColor)
    public static let inkFaint = ink.opacity(0.12)
    public static let accent = Color(red: 196 / 255, green: 59 / 255, blue: 46 / 255)
    public static let boxLine = ink.opacity(0.08)

    /// Elevated card surface, distinct from `paper` for light-mode elevation contrast.
    public static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? surfaceDark : .white
    })

    // MARK: - Chip Styles

    public static let chipNewBackground = ink.opacity(0.08)
    public static let chipNewForeground = ink
    public static let chipLearnBackground = accent.opacity(0.12)
    public static let chipLearnForeground = accent
    public static let chipDueBackground = ink
    public static let chipDueForeground = paper

    // MARK: - Shape

    public static let radiusLarge: CGFloat = 20
    public static let radiusMedium: CGFloat = 16

    // MARK: - Typography

    /// Content glyphs (answer targets, trace guides): scales with Dynamic Type, matching
    /// prompt/answer metadata text (reading, English, hint).
    public static func japaneseDisplayFont(size: CGFloat, bold: Bool = false) -> Font {
        let fontName = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        return Font.custom(fontName, size: size)
    }

    /// Answer glyphs and guide-box glyphs: fixed size regardless of Dynamic Type — they're
    /// the content being written, not chrome.
    public static func japaneseDisplayFontFixed(size: CGFloat, bold: Bool = false) -> Font {
        let fontName = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        return Font.custom(fontName, fixedSize: size)
    }
}

/// Scales a literal point size with Dynamic Type, relative to `.body`, while preserving the
/// design's exact point size at the default content size category.
private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// Chrome text: scales with Dynamic Type. Use for all UI text that isn't the answer
    /// glyphs, trace-guide glyphs, or guide-box content.
    func kakitoriFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }
}

// MARK: - Motion Support

public extension KakitoriTheme {
    /// Card-to-card transition: crossfade + slight horizontal slide when motion is enabled,
    /// plain opacity crossfade when Reduce Motion is on.
    static func cardTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            AnyTransition.opacity
        } else {
            AnyTransition.asymmetric(
                insertion: AnyTransition.opacity.combined(with: .move(edge: .trailing)),
                removal: AnyTransition.opacity.combined(with: .move(edge: .leading))
            )
        }
    }

    /// Emphasis transition: scale-in normally, plain crossfade under Reduce Motion.
    static func emphasisTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            AnyTransition.opacity
        } else {
            AnyTransition.scale.combined(with: .opacity)
        }
    }
}
