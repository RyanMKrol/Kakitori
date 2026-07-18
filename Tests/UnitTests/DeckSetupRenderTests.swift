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
            availableModes: [.trace, .listen, .recall, .mixed],
            onStart: { _ in },
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
}
