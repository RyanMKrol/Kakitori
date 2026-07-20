import PencilKit
import SwiftUI

@MainActor
@Observable
final class WritingCanvasController {
    private(set) var isDrawingEmpty = true
    weak var canvasView: PKCanvasView?

    func undo() {
        canvasView?.undoManager?.undo()
    }

    func clear() {
        canvasView?.drawing = PKDrawing()
    }

    func drawingDidChange(isEmpty: Bool) {
        isDrawingEmpty = isEmpty
    }
}

struct WritingCanvas: UIViewRepresentable {
    static let penWidth: CGFloat = 6

    let controller: WritingCanvasController

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.tool = Self.inkingTool(for: canvasView.traitCollection)
        canvasView.delegate = context.coordinator
        canvasView.accessibilityIdentifier = "writing-canvas"

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        canvasView.addInteraction(pencilInteraction)

        // PKInkingTool resolves a dynamic color once, against the trait collection active
        // when the tool is created, and never re-resolves it — so the tool must be rebuilt
        // with a freshly-resolved concrete color whenever the appearance changes.
        canvasView.registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]
        ) { (view: PKCanvasView, _: UITraitCollection) in
            view.tool = Self.inkingTool(for: view.traitCollection)
        }

        controller.canvasView = canvasView
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context _: Context) {
        canvasView.tool = Self.inkingTool(for: canvasView.traitCollection)
    }

    private static func inkingTool(for traitCollection: UITraitCollection) -> PKInkingTool {
        PKInkingTool(.pen, color: KakitoriTheme.resolvedInkColor(for: traitCollection), width: penWidth)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        let controller: WritingCanvasController

        init(controller: WritingCanvasController) {
            self.controller = controller
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            controller.drawingDidChange(isEmpty: canvasView.drawing.strokes.isEmpty)
        }

        func pencilInteractionDidTap(_: UIPencilInteraction) {
            controller.undo()
        }
    }
}

#Preview("Writing Canvas") {
    let controller = WritingCanvasController()

    return VStack(spacing: 16) {
        WritingCanvas(controller: controller)
            .frame(width: 500, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(KakitoriTheme.inkFaint, lineWidth: 1)
            )

        HStack(spacing: 16) {
            Button("Undo") {
                controller.undo()
            }
            .accessibilityIdentifier("canvas-undo")

            Button("Clear") {
                controller.clear()
            }
            .accessibilityIdentifier("canvas-clear")
        }
    }
    .padding()
    .background(KakitoriTheme.paper)
}
