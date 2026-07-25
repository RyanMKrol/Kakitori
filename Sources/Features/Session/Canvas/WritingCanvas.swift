import PencilKit
import SwiftUI

@MainActor
@Observable
final class WritingCanvasController {
    private(set) var isDrawingEmpty = true
    weak var canvasView: PKCanvasView?

    /// The nib angle the brush is pinned to, in radians, or nil while it follows the pencil.
    /// Observed: the brush menu shows and edits it.
    private(set) var lockedBrushAngle: CGFloat?

    /// Whether the brush menu is on screen. Set by a Pencil hold, cleared by the menu itself.
    var isBrushMenuPresented = false

    /// `@ObservationIgnored` on purpose: nothing in a view body reads this, and it is assigned from
    /// `updateUIView` — mutating tracked state there would be a write during the view update.
    @ObservationIgnored var colorScheme: ColorScheme = .light

    func undo() {
        canvasView?.undoManager?.undo()
    }

    /// Pins the brush's face to `radians` so it stops rotating with the pencil — the point being
    /// that the angle that draws well and the grip that feels comfortable aren't the same angle.
    func lockBrushAngle(to radians: CGFloat) {
        lockedBrushAngle = radians
        applyInk()
    }

    func releaseBrushAngleLock() {
        lockedBrushAngle = nil
        applyInk()
    }

    /// Shows an angle without committing to it, so the nib tracks the pencil while it's being
    /// rolled during a squeeze. Committing is `lockBrushAngle(to:)`.
    func previewBrushAngle(_ radians: CGFloat) {
        applyInk(angle: radians)
    }

    func applyInk() {
        applyInk(angle: lockedBrushAngle)
    }

    private func applyInk(angle: CGFloat?) {
        canvasView?.tool = WritingCanvas.inkingTool(for: colorScheme, angle: angle)
    }

    /// Wipes the canvas, but registers the wipe with the undo manager first. Clearing is the one
    /// destructive thing on this screen and it now has a hardware trigger (a Pencil squeeze), so a
    /// mis-fire has to be recoverable — Undo (button or Pencil double-tap) puts the writing back.
    func clear() {
        guard let canvasView, !canvasView.drawing.strokes.isEmpty else { return }

        let previous = canvasView.drawing
        canvasView.undoManager?.registerUndo(withTarget: canvasView) { canvas in
            canvas.drawing = previous
        }
        canvasView.drawing = PKDrawing()
        drawingDidChange(isEmpty: true)
    }

    func drawingDidChange(isEmpty: Bool) {
        isDrawingEmpty = isEmpty
    }
}

struct WritingCanvas: UIViewRepresentable {
    /// Kana and kanji are brush forms: a stroke swells where the brush is pressed and tapers into
    /// the はらい sweep at the end. A uniform-width `.pen` flattens that away, so writing practice
    /// looks nothing like the model the user is copying. `.fountainPen` modulates width per point
    /// from pressure, speed and tilt, which is the closest PencilKit ink to a brush. It varies on
    /// speed alone, so finger drawing gets the thick/thin too — pressure is a bonus with a Pencil.
    static let inkType: PKInkingTool.InkType = .fountainPen

    /// The BASE width. PencilKit scales each point either side of it from the input dynamics, so
    /// the drawn stroke ranges roughly half to double this. Sized up from the old flat 6pt pen (a
    /// tapering stroke needs headroom above the old width to read as a brush at its thickest), then
    /// trimmed back ~17% from the first pass at 9pt, which wrote a touch heavy on real hardware.
    static let brushWidth: CGFloat = 7.5

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

    func updateUIView(_: PKCanvasView, context _: Context) {
        // SwiftUI re-invokes updateUIView when `colorScheme` changes, so the ink re-resolves to a
        // concrete near-black (light) / near-white (dark) colour and tracks live appearance switches.
        // Rebuilt through the controller so a locked brush angle survives the rebuild.
        controller.colorScheme = colorScheme
        controller.applyInk()
    }

    /// - Parameter angle: a fixed nib angle in radians, or nil to let the nib follow the pencil.
    ///   Pinning the angle needs iOS 26; below that the brush always follows the pencil.
    static func inkingTool(for colorScheme: ColorScheme, angle: CGFloat? = nil) -> PKInkingTool {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let trait = UITraitCollection(userInterfaceStyle: style)
        let color = KakitoriTheme.resolvedInkColor(for: trait)

        if let angle, canLockBrushAngle {
            if #available(iOS 26.0, *) {
                return PKInkingTool(inkType, color: color, width: resolvedWidth, azimuth: angle)
            }
        }

        return PKInkingTool(inkType, color: color, width: resolvedWidth)
    }

    /// Whether this OS can pin an ink's nib angle at all — `PKInkingTool`'s azimuth initialiser is
    /// iOS 26, and the app still runs on 18.
    static var canLockBrushAngle: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    /// Each ink has its own legal width range and PencilKit silently clamps out-of-range values —
    /// so clamp deliberately, and let the test assert the base width is one the ink can honour.
    static var resolvedWidth: CGFloat {
        let range = inkType.validWidthRange
        return min(max(brushWidth, range.lowerBound), range.upperBound)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        let controller: WritingCanvasController

        /// When the squeeze in progress started. Reset on every `.began` so an interrupted squeeze
        /// can't leak into the next one.
        private var squeezeStart: TimeInterval?

        init(controller: WritingCanvasController) {
            self.controller = controller
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            controller.drawingDidChange(isEmpty: canvasView.drawing.strokes.isEmpty)
        }

        func pencilInteractionDidTap(_: UIPencilInteraction) {
            controller.undo()
        }

        /// The Pencil Pro squeeze, told apart by how long it's held:
        ///
        /// - A quick squeeze clears the canvas — reset and go again without reaching for the button.
        /// - Holding opens the brush menu, which is where the angle lock lives.
        ///
        /// The system plays the Pencil's haptic on recognition, so there's none to fire here.
        /// Honours the Settings preference: `.ignore` means the user turned squeeze off (or turned
        /// off Pencil interactions in Accessibility), and acting anyway ignores that choice.
        func pencilInteraction(_: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            guard UIPencilInteraction.preferredSqueezeAction != .ignore else { return }

            switch squeeze.phase {
            case .began:
                squeezeStart = squeeze.timestamp

            case .ended:
                let outcome = PencilSqueeze.outcome(
                    duration: squeeze.timestamp - (squeezeStart ?? squeeze.timestamp),
                    canLockAngle: WritingCanvas.canLockBrushAngle
                )
                squeezeStart = nil

                switch outcome {
                case .clearCanvas:
                    controller.clear()
                case .showBrushMenu:
                    controller.isBrushMenuPresented = true
                }

            case .changed:
                break

            case .cancelled:
                squeezeStart = nil

            @unknown default:
                squeezeStart = nil
            }
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
