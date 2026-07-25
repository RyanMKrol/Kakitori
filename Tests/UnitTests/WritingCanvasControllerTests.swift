@testable import Kakitori
import PencilKit
import SwiftUI
import XCTest

@MainActor
final class WritingCanvasControllerTests: XCTestCase {
    func testStartsWithEmptyDrawing() {
        let controller = WritingCanvasController()
        XCTAssertTrue(controller.isDrawingEmpty)
    }

    func testDrawingDidChangeUpdatesEmptyState() {
        let controller = WritingCanvasController()
        controller.drawingDidChange(isEmpty: false)
        XCTAssertFalse(controller.isDrawingEmpty)

        controller.drawingDidChange(isEmpty: true)
        XCTAssertTrue(controller.isDrawingEmpty)
    }

    func testUndoAndClearAreNoOpsWithoutAttachedCanvas() {
        let controller = WritingCanvasController()
        controller.undo()
        controller.clear()
        XCTAssertNil(controller.canvasView)
    }

    /// The brush base width has to be one the ink can actually honour — PencilKit clamps silently,
    /// so a width outside the range would just quietly become a different stroke than intended.
    func testBrushWidthIsWithinTheInkTypesSupportedRange() {
        let range = WritingCanvas.inkType.validWidthRange
        print("fountainPen valid width range: \(range), default: \(WritingCanvas.inkType.defaultWidth)")

        XCTAssertTrue(range.contains(WritingCanvas.brushWidth), "valid range is \(range)")
        XCTAssertEqual(WritingCanvas.resolvedWidth, WritingCanvas.brushWidth)
    }

    /// The ink is pressure/speed responsive on purpose — a uniform-width ink writes kana flat.
    func testInkTypeIsThePressureResponsiveBrush() {
        XCTAssertEqual(WritingCanvas.inkType, .fountainPen)

        let tool = WritingCanvas.inkingTool(for: .light)
        XCTAssertEqual(tool.inkType, .fountainPen)
        XCTAssertEqual(tool.width, WritingCanvas.resolvedWidth)
    }
}
