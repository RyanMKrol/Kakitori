import SwiftUI

public enum KakitoriTheme {
    // MARK: - Palette

    public static let paper = Color(red: 250 / 255, green: 248 / 255, blue: 244 / 255)
    public static let ink = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)
    public static let inkFaint = ink.opacity(0.12)
    public static let accent = Color(red: 196 / 255, green: 59 / 255, blue: 46 / 255)
    public static let boxLine = ink.opacity(0.08)

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

    public static func japaneseDisplayFont(size: CGFloat, bold: Bool = false) -> Font {
        let fontName = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        return Font.custom(fontName, size: size)
    }

    public static func smallCapsLabel(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold)
    }
}
