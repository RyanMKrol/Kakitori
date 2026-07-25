@testable import Kakitori
import SwiftUI
import XCTest

final class DeckSetupRenderTests: XCTestCase {
    @MainActor
    func testDeckSetupSheetRender() throws {
        let sheet = DeckSetupSheet(
            jpTitle: "ひらがな",
            enTitle: "Hiragana",
            dueCount: 10,
            isCaughtUp: false,
            availableModes: [.trace, .listen, .mixed],
            onStart: { _ in },
            onStartFreeStudy: { _ in },
            onClose: {}
        )

        let hostingController = UIHostingController(rootView: sheet)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 560, height: 700)

        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2

        guard let uiImage = renderer.uiImage else {
            XCTFail("Failed to render image")
            return
        }

        let screenshotDir = URL(
            fileURLWithPath: #filePath
        ).deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("screenshots")

        try FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)

        let screenshotPath = screenshotDir.appendingPathComponent("T037-decksetup.png")
        if let pngData = uiImage.pngData() {
            try pngData.write(to: screenshotPath)
        } else {
            XCTFail("Failed to convert image to PNG")
        }
    }

    /// The dueCount == 0 variant: caught-up messaging inline, mode picker still there, blue
    /// Free Study button instead of the red "Start writing" one.
    @MainActor
    func testDeckSetupSheetCaughtUpRender() throws {
        try renderCaughtUpSheet(width: 560, height: 700, name: "T090-decksetup-caughtup.png")
    }

    @MainActor
    func testDeckSetupSheetCaughtUpCompactRender() throws {
        try renderCaughtUpSheet(width: 390, height: 750, name: "T090-decksetup-caughtup-compact.png")
    }

    @MainActor
    private func renderCaughtUpSheet(width: CGFloat, height: CGFloat, name: String) throws {
        let sheet = DeckSetupSheet(
            jpTitle: "ひらがな",
            enTitle: "Hiragana",
            dueCount: 0,
            isCaughtUp: true,
            availableModes: [.trace, .listen, .translate, .mixed],
            onStart: { _ in },
            onStartFreeStudy: { _ in },
            onClose: {}
        )
        .frame(width: width, height: height)

        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2

        guard let uiImage = renderer.uiImage else {
            XCTFail("Failed to render image")
            return
        }

        let screenshotDir = URL(
            fileURLWithPath: #filePath
        ).deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("screenshots")

        try FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)

        let screenshotPath = screenshotDir.appendingPathComponent(name)
        if let pngData = uiImage.pngData() {
            try pngData.write(to: screenshotPath)
        } else {
            XCTFail("Failed to convert image to PNG")
        }
    }
}
