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

    // MARK: - Brush angle lock

    func testBrushAngleStartsFollowingThePencil() {
        let controller = WritingCanvasController()

        XCTAssertNil(controller.lockedBrushAngle)
    }

    func testLockingAndReleasingTheBrushAngle() {
        let controller = WritingCanvasController()
        controller.canvasView = PKCanvasView()

        controller.lockBrushAngle(to: .pi / 4)
        XCTAssertEqual(controller.lockedBrushAngle ?? 0, .pi / 4, accuracy: 0.0001)

        controller.releaseBrushAngleLock()
        XCTAssertNil(controller.lockedBrushAngle, "there has to be a way back to following the pencil")
    }

    /// Dragging the dial previews an angle on the canvas without committing to it, so letting go
    /// somewhere you didn't mean doesn't leave the brush stuck there.
    func testPreviewingAnAngleDoesNotLockIt() {
        let controller = WritingCanvasController()
        controller.canvasView = PKCanvasView()

        controller.previewBrushAngle(.pi / 3)

        XCTAssertNil(controller.lockedBrushAngle)
    }

    /// The angle has to survive a light/dark change — that rebuilds the ink, and an ink rebuilt
    /// from scratch would quietly go back to following the pencil mid-session.
    func testLockedAngleSurvivesAnInkRebuild() {
        let controller = WritingCanvasController()
        controller.canvasView = PKCanvasView()
        controller.lockBrushAngle(to: .pi / 4)

        controller.colorScheme = .dark
        controller.applyInk()

        XCTAssertEqual(controller.lockedBrushAngle ?? 0, .pi / 4, accuracy: 0.0001)
    }

    /// The lock is what the menu exists for, so on an OS that can't pin an angle the menu would be
    /// an empty box — the gesture and the button both check this before offering it.
    func testAngleLockingAvailabilityMatchesTheRunningOS() {
        if #available(iOS 26.0, *) {
            XCTAssertTrue(WritingCanvas.canLockBrushAngle)
        } else {
            XCTAssertFalse(WritingCanvas.canLockBrushAngle)
        }
    }

    /// The ink is pressure/speed responsive on purpose — a uniform-width ink writes kana flat.
    func testInkTypeIsThePressureResponsiveBrush() {
        XCTAssertEqual(WritingCanvas.inkType, .fountainPen)

        let tool = WritingCanvas.inkingTool(for: .light)
        XCTAssertEqual(tool.inkType, .fountainPen)
        XCTAssertEqual(tool.width, WritingCanvas.resolvedWidth)
    }
}
