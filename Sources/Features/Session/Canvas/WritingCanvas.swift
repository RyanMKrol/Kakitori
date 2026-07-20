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

    /// Drives the ink colour. Comes from the SwiftUI `\.colorScheme` environment (authoritative for
    /// light/dark), NOT the PKCanvasView's own trait collection — that can still read `.light`/
    /// `.unspecified` when the tool is built, which resolved the ink to near-black on a dark canvas.
    var colorScheme: ColorScheme = .light

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        // PencilKit auto-INVERTS stroke colours when the canvas's own trait is dark (to keep dark
        // ink readable on a dark background) — which flipped our near-white ink back to near-black.
        // Pin the canvas to a light trait so PencilKit never inverts, then we drive the actual ink
        // colour ourselves from the SwiftUI colorScheme below. The canvas background is `.clear`, so
        // the dark app background still shows through — only the ink adaptation is disabled.
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.tool = Self.inkingTool(for: colorScheme)
        canvasView.delegate = context.coordinator
        canvasView.accessibilityIdentifier = "writing-canvas"

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        canvasView.addInteraction(pencilInteraction)

        controller.canvasView = canvasView
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context _: Context) {
        // SwiftUI re-invokes updateUIView when `colorScheme` changes, so the ink re-resolves to a
        // concrete near-black (light) / near-white (dark) colour and tracks live appearance switches.
        canvasView.tool = Self.inkingTool(for: colorScheme)
    }

    private static func inkingTool(for colorScheme: ColorScheme) -> PKInkingTool {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let trait = UITraitCollection(userInterfaceStyle: style)
        return PKInkingTool(.pen, color: KakitoriTheme.resolvedInkColor(for: trait), width: penWidth)
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
