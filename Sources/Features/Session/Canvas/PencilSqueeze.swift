import CoreGraphics
import Foundation

/// What a completed Pencil squeeze should do on the writing canvas.
enum PencilSqueezeOutcome: Equatable {
    /// Wipe the canvas — the quick "reset and go again" squeeze.
    case clearCanvas
    /// Pin the brush's face to the angle the pencil was rolled to.
    case lockBrushAngle
    /// Drop a previous lock and let the brush follow the pencil again.
    case releaseBrushAngleLock
}

/// Decides what a squeeze meant, so one gesture can carry both the quick canvas wipe and the
/// brush-angle lock. Pure input → outcome, because the gesture itself only exists on Pencil Pro
/// hardware that no simulator can produce: this is the part that can actually be tested.
enum PencilSqueeze {
    /// A squeeze shorter than this, with no roll, reads as a deliberate quick press rather than
    /// someone settling the pencil into a comfortable grip.
    static let clearMaxDuration: TimeInterval = 0.4

    /// Roughly 7°. Below this the pencil hasn't really been rolled — it's the wobble of gripping
    /// and squeezing, and treating it as a rotation would relock the brush every time.
    static let rotationThreshold: CGFloat = 0.12

    /// - Parameters:
    ///   - duration: seconds between the squeeze's begin and end.
    ///   - rollDelta: change in barrel roll over the squeeze, or nil when the pencil never hovered
    ///     in range and no pose was reported.
    ///   - canLockAngle: whether the running OS can pin an ink's angle at all. Without it there is
    ///     no lock to set or release, so every squeeze is a clear.
    static func outcome(duration: TimeInterval, rollDelta: CGFloat?, canLockAngle: Bool) -> PencilSqueezeOutcome {
        guard canLockAngle else { return .clearCanvas }

        if let rollDelta, abs(rollDelta) >= rotationThreshold {
            return .lockBrushAngle
        }

        // Held, but not rolled: the way back out of a lock, and the reason holding still isn't
        // just a slow clear — a clear you can trigger by hesitating would be infuriating.
        return duration < clearMaxDuration ? .clearCanvas : .releaseBrushAngleLock
    }
}
