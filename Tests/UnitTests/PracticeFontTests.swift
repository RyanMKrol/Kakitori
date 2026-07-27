@testable import Kakitori
import SwiftUI
import UIKit
import XCTest

/// The bundled face is the whole reason this exists: iOS ships no Japanese face that draws the
/// handwritten forms, so if Klee fails to register the app falls back to a system face and every
/// glyph in it — answers, trace guides, deck titles — silently goes back to teaching printed
/// letterforms. Nothing on screen would look broken.
final class PracticeFontTests: XCTestCase {
    func testTheBundledFaceIsWhatResolves() {
        XCTAssertEqual(PracticeFont.resolvedFontName(bold: false), "KleeOne-Regular")
        XCTAssertEqual(PracticeFont.resolvedFontName(bold: true), "KleeOne-SemiBold")
        XCTAssertTrue(PracticeFont.isBundledFontRegistered)
    }

    /// Guards the bundling itself: a font registered through UIAppFonts is loadable by PostScript
    /// name, and this is what breaks if the Info.plist key or the resource phase is lost.
    func testBothWeightsAreRegisteredWithTheSystem() {
        for name in ["KleeOne-Regular", "KleeOne-SemiBold"] {
            XCTAssertNotNil(
                UIFont(name: name, size: 20),
                "\(name) is not registered — check UIAppFonts in project.yml and the Fonts resource phase"
            )
        }
    }

    /// Every Japanese glyph in the app goes through the theme, so the theme is what has to be
    /// wired to the bundled face — a hardcoded system name here would undo the whole thing.
    func testTheThemeDrawsJapaneseInTheBundledFace() {
        XCTAssertEqual(KakitoriTheme.japaneseDisplayFont(size: 20), PracticeFont.font(size: 20))
        XCTAssertEqual(
            KakitoriTheme.japaneseDisplayFontFixed(size: 20, bold: true),
            PracticeFont.fixedFont(size: 20, bold: true)
        )
        XCTAssertNotEqual(
            KakitoriTheme.japaneseDisplayFontFixed(size: 20, bold: true),
            Font.custom("HiraMinProN-W6", fixedSize: 20),
            "the old Mincho face must not be what Japanese renders in"
        )
    }
}
