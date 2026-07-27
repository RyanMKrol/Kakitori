@testable import Kakitori
import UIKit
import XCTest

/// The bundled faces are the whole reason this exists: iOS ships no Japanese face that draws the
/// handwritten forms, so if a bundled font fails to register the app silently substitutes the
/// system face and the option becomes a lie — same shapes, different label.
final class PracticeFontTests: XCTestCase {
    func testEveryOfferedFaceResolvesToARealFont() {
        for face in PracticeFont.allCases {
            XCTAssertTrue(
                face.isAvailable,
                "\(face.displayName) resolved to nothing — a bundled font is missing from the target"
            )
            XCTAssertNotNil(face.resolvedFontName(bold: false))
            XCTAssertNotNil(face.resolvedFontName(bold: true))
        }
    }

    /// The bundled ones must resolve to THEIR OWN file, not to a system fallback that happens to
    /// exist — that's the failure mode that would quietly undo the point of bundling them.
    func testBundledFacesResolveToTheBundledFiles() {
        XCTAssertEqual(PracticeFont.kleeOne.resolvedFontName(bold: true), "KleeOne-SemiBold")
        XCTAssertEqual(PracticeFont.kleeOne.resolvedFontName(bold: false), "KleeOne-SemiBold")
        XCTAssertEqual(PracticeFont.zenKurenaido.resolvedFontName(bold: true), "ZenKurenaido-Regular")
    }

    func testTheSystemGothicIsStillTheReference() {
        XCTAssertEqual(PracticeFont.gothic.resolvedFontName(bold: true), "HiraginoSans-W6")
        XCTAssertFalse(PracticeFont.gothic.usesHandwrittenForms, "the system gothic draws printed forms")
    }

    func testTheComparisonOffersBothFormStyles() {
        let handwritten = PracticeFont.allCases.filter(\.usesHandwrittenForms)
        XCTAssertFalse(handwritten.isEmpty, "there has to be something to compare the gothic against")
        XCTAssertTrue(
            PracticeFont.allCases.contains { !$0.usesHandwrittenForms },
            "and the printed-form reference has to stay in the comparison"
        )
    }

    /// Guards the bundling itself: a font registered through UIAppFonts is loadable by PostScript
    /// name, and this is what breaks if the Info.plist key or the resource phase is lost.
    func testBundledFontsAreRegisteredWithTheSystem() {
        for name in ["KleeOne-SemiBold", "ZenKurenaido-Regular"] {
            XCTAssertNotNil(
                UIFont(name: name, size: 20),
                "\(name) is not registered — check UIAppFonts in project.yml and the Fonts resource phase"
            )
        }
    }
}
