import PencilKit
import SwiftUI

@MainActor
@Observable
final class WritingCanvasController {
    private(set) var isDrawingEmpty = true
    weak var canvasView: PKCanvasView?

    /// The nib angle the brush is pinned to, in radians, or nil while it follows the pencil.
    ///
    /// `@ObservationIgnored` on purpose: nothing in a view body reads these, and the ink is applied
    /// straight to the canvas below. Observing them would mean mutating tracked state from
    /// `updateUIView`, which runs inside the view update.
    @ObservationIgnored private(set) var lockedBrushAngle: CGFloat?

    /// Set from `updateUIView`, so the ink can be rebuilt (on an angle change) without the view.
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

        /// Squeeze-in-progress state: when it started, the roll it started at, and the roll it was
        /// last seen at. Reset on every `.began` so an interrupted squeeze can't leak into the next.
        private var squeezeStart: TimeInterval?
        private var squeezeStartRoll: CGFloat?
        private var squeezeLatestRoll: CGFloat?
        private var brushAngleBeforeSqueeze: CGFloat?

        init(controller: WritingCanvasController) {
            self.controller = controller
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            controller.drawingDidChange(isEmpty: canvasView.drawing.strokes.isEmpty)
        }

        func pencilInteractionDidTap(_: UIPencilInteraction) {
            controller.undo()
        }

        /// The Pencil Pro squeeze carries two things, told apart by how long it's held:
        ///
        /// - A quick squeeze clears the canvas — reset and go again without reaching for the button.
        /// - Squeezing, rolling the pencil, then releasing pins the brush's face to that angle. The
        ///   angle a brush draws well at and the grip that's comfortable to write with aren't the
        ///   same angle, and without this the only way to fix one is to give up the other.
        /// - Holding without rolling releases the pin, so there's a way back out.
        ///
        /// The system plays the Pencil's haptic on recognition, so there's none to fire here.
        /// Honours the Settings preference: `.ignore` means the user turned squeeze off (or turned
        /// off Pencil interactions in Accessibility), and acting anyway ignores that choice.
        func pencilInteraction(_: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            guard UIPencilInteraction.preferredSqueezeAction != .ignore else { return }

            // `hoverPose` is nil unless the pencil is in hover range, so a squeeze made with the
            // pencil away from the screen reports no roll at all — hence the optionals throughout.
            let roll = squeeze.hoverPose?.rollAngle

            switch squeeze.phase {
            case .began:
                squeezeStart = squeeze.timestamp
                squeezeStartRoll = roll
                squeezeLatestRoll = roll
                brushAngleBeforeSqueeze = controller.lockedBrushAngle

            case .changed:
                if let roll {
                    squeezeStartRoll = squeezeStartRoll ?? roll
                    squeezeLatestRoll = roll
                    // Follow the roll live, so the nib angle being chosen is visible while
                    // choosing it rather than a surprise on release.
                    controller.previewBrushAngle(roll)
                }

            case .ended:
                applySqueeze(endedAt: squeeze.timestamp, roll: roll)
                resetSqueezeTracking()

            case .cancelled:
                restoreBrushAngleFromBeforeSqueeze()
                resetSqueezeTracking()

            @unknown default:
                restoreBrushAngleFromBeforeSqueeze()
                resetSqueezeTracking()
            }
        }

        private func applySqueeze(endedAt timestamp: TimeInterval, roll: CGFloat?) {
            let finalRoll = roll ?? squeezeLatestRoll
            let rollDelta = zip2(squeezeStartRoll, finalRoll).map { $1 - $0 }

            let outcome = PencilSqueeze.outcome(
                duration: timestamp - (squeezeStart ?? timestamp),
                rollDelta: rollDelta,
                canLockAngle: WritingCanvas.canLockBrushAngle
            )

            switch outcome {
            case .clearCanvas:
                // A live preview may have nudged the nib while the pencil was gripped; this
                // squeeze turned out not to be about the angle, so put it back.
                restoreBrushAngleFromBeforeSqueeze()
                controller.clear()

            case .lockBrushAngle:
                if let finalRoll {
                    controller.lockBrushAngle(to: finalRoll)
                } else {
                    restoreBrushAngleFromBeforeSqueeze()
                }

            case .releaseBrushAngleLock:
                controller.releaseBrushAngleLock()
            }
        }

        private func restoreBrushAngleFromBeforeSqueeze() {
            if let previous = brushAngleBeforeSqueeze {
                controller.lockBrushAngle(to: previous)
            } else {
                controller.releaseBrushAngleLock()
            }
        }

        private func resetSqueezeTracking() {
            squeezeStart = nil
            squeezeStartRoll = nil
            squeezeLatestRoll = nil
            brushAngleBeforeSqueeze = nil
        }

        /// Both-or-nothing pairing of two optionals — a roll delta needs a start AND an end.
        private func zip2<A, B>(_ first: A?, _ second: B?) -> (A, B)? {
            guard let first, let second else { return nil }
            return (first, second)
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
