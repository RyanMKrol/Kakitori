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
        canvasView.tool = PKInkingTool(.pen, color: KakitoriTheme.inkUIColor, width: Self.penWidth)
        canvasView.delegate = context.coordinator
        canvasView.accessibilityIdentifier = "writing-canvas"

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        canvasView.addInteraction(pencilInteraction)

        controller.canvasView = canvasView
        return canvasView
    }

    func updateUIView(_: PKCanvasView, context _: Context) {}

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
