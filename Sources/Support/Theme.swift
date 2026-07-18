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

    public static func japaneseDisplayFont(size: CGFloat, bold: Bool = false) -> Font {
        let fontName = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        return Font.custom(fontName, size: size)
    }

    public static func smallCapsLabel(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold)
    }
}
