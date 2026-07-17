@testable import Kakitori
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
}
