import CoreGraphics
import Foundation

/// What a completed Pencil squeeze should do on the writing canvas.
enum PencilSqueezeOutcome: Equatable {
    /// Wipe the canvas — the quick "reset and go again" squeeze.
    case clearCanvas
    /// Open the brush menu, which is where the angle lock and the deliberate actions live.
    case showBrushMenu
}

/// Decides what a squeeze meant, so one gesture can carry both the quick canvas wipe and a way in
/// to the brush controls. Pure input → outcome, because the gesture itself only exists on Pencil
/// Pro hardware that no simulator can produce: this is the part that can actually be tested.
///
/// An earlier version tried to read the angle straight off the gesture — squeeze, roll, release.
/// That depended on `UIPencilInteraction.Squeeze.hoverPose`, which is nil unless the pencil happens
/// to be hovering in range, so on a squeeze made away from the screen there was no roll to read and
/// the lock silently never engaged. The angle is now chosen in the menu, where it doesn't depend on
/// the pencil's pose at the moment of a gesture.
enum PencilSqueeze {
    /// A squeeze shorter than this reads as a deliberate quick press. Longer is a hold, which is
    /// how you ask for the menu.
    static let clearMaxDuration: TimeInterval = 0.4

    /// - Parameters:
    ///   - duration: seconds between the squeeze's begin and end.
    ///   - canLockAngle: whether the running OS can pin an ink's angle at all. Without it the menu
    ///     has nothing to offer that the buttons don't, so every squeeze is a clear.
    static func outcome(duration: TimeInterval, canLockAngle: Bool) -> PencilSqueezeOutcome {
        guard canLockAngle else { return .clearCanvas }

        return duration < clearMaxDuration ? .clearCanvas : .showBrushMenu
    }
}
