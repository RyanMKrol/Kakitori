@testable import Kakitori
import SwiftUI
import XCTest

final class SummaryCompactRenderTests: XCTestCase {
    @MainActor
    func testSummaryCompactRender() throws {
        let summary = SummaryView(
            cardsWritten: 12,
            minutes: 6,
            againCount: 1,
            hardCount: 2,
            goodCount: 7,
            easyCount: 2,
            streakDays: 5,
            onBackToDecks: {},
            onStudyAnother: {}
        )
        .environment(\.horizontalSizeClass, .compact)
        .frame(width: 390, height: 844)

        let renderer = ImageRenderer(content: summary)
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

        let screenshotPath = screenshotDir.appendingPathComponent("T079-summary-compact.png")
        if let pngData = uiImage.pngData() {
            try pngData.write(to: screenshotPath)
        } else {
            XCTFail("Failed to convert image to PNG")
        }
    }
}
