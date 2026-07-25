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

    /// Clearing is the one destructive action on the writing screen and a Pencil squeeze can now
    /// trigger it by accident, so it has to be recoverable through the normal Undo.
    func testClearRegistersAnUndoThatRestoresTheWriting() throws {
        // Hosted in a window on purpose: `undoManager` resolves up the responder chain, so a
        // detached canvas has none and would exercise a clear() that silently skips registration.
        let canvas = PKCanvasView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let window = UIWindow(frame: canvas.frame)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(canvas)
        window.makeKeyAndVisible()

        let controller = WritingCanvasController()
        controller.canvasView = canvas
        canvas.drawing = Self.makeDrawing()

        let undoManager = try XCTUnwrap(canvas.undoManager, "hosted canvas should resolve an undo manager")
        controller.clear()

        XCTAssertTrue(canvas.drawing.strokes.isEmpty, "clear wipes the canvas")
        XCTAssertTrue(controller.isDrawingEmpty)
        XCTAssertTrue(undoManager.canUndo, "clear must be undoable — a Pencil squeeze can trigger it")

        undoManager.undo()
        XCTAssertEqual(canvas.drawing.strokes.count, 1, "undo puts the writing back")
    }

    func testClearOnAnEmptyCanvasIsANoOp() {
        let canvas = PKCanvasView()
        let controller = WritingCanvasController()
        controller.canvasView = canvas

        controller.clear()

        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
    }

    private static func makeDrawing() -> PKDrawing {
        let points = (0 ..< 5).map { index in
            PKStrokePoint(
                location: CGPoint(x: Double(index) * 10, y: 0),
                timeOffset: Double(index) * 0.01,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_700_000_000))
        return PKDrawing(strokes: [PKStroke(ink: PKInk(WritingCanvas.inkType, color: .black), path: path)])
    }

    /// The ink is pressure/speed responsive on purpose — a uniform-width ink writes kana flat.
    func testInkTypeIsThePressureResponsiveBrush() {
        XCTAssertEqual(WritingCanvas.inkType, .fountainPen)

        let tool = WritingCanvas.inkingTool(for: .light)
        XCTAssertEqual(tool.inkType, .fountainPen)
        XCTAssertEqual(tool.width, WritingCanvas.resolvedWidth)
    }
}
