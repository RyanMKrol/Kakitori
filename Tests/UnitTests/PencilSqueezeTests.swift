import CoreGraphics
@testable import Kakitori
import XCTest

/// The squeeze gesture itself only exists on Pencil Pro hardware, which no simulator can produce —
/// so what's pinned down here is the decision it feeds: which of the two actions a given squeeze
/// meant. Getting this wrong wipes someone's writing when they were adjusting their grip.
final class PencilSqueezeTests: XCTestCase {
    func testQuickSqueezeWithoutRollClearsTheCanvas() {
        let outcome = PencilSqueeze.outcome(duration: 0.15, rollDelta: 0, canLockAngle: true)

        XCTAssertEqual(outcome, .clearCanvas)
    }

    func testRollingWhileSqueezingLocksTheBrushAngle() {
        let outcome = PencilSqueeze.outcome(duration: 1.2, rollDelta: 0.9, canLockAngle: true)

        XCTAssertEqual(outcome, .lockBrushAngle)
    }

    /// Rolling the other way is still rolling.
    func testRollDirectionDoesNotMatter() {
        let outcome = PencilSqueeze.outcome(duration: 1.2, rollDelta: -0.9, canLockAngle: true)

        XCTAssertEqual(outcome, .lockBrushAngle)
    }

    /// A fast flick of the wrist is a deliberate rotation even if the squeeze was brief — the roll
    /// is what makes it about the angle, not the clock.
    func testAQuickSqueezeThatRollsStillLocks() {
        let outcome = PencilSqueeze.outcome(duration: 0.2, rollDelta: 0.5, canLockAngle: true)

        XCTAssertEqual(outcome, .lockBrushAngle)
    }

    /// Gripping and squeezing wobbles the pencil a little. Treating that as a rotation would
    /// relock the brush on every clear.
    func testWobbleBelowTheThresholdIsNotARotation() {
        let wobble = PencilSqueeze.rotationThreshold * 0.9

        XCTAssertEqual(
            PencilSqueeze.outcome(duration: 0.2, rollDelta: wobble, canLockAngle: true),
            .clearCanvas
        )
    }

    func testHoldingWithoutRollingReleasesTheLock() {
        let outcome = PencilSqueeze.outcome(duration: 1.5, rollDelta: 0, canLockAngle: true)

        XCTAssertEqual(outcome, .releaseBrushAngleLock, "there has to be a way back out of a lock")
    }

    /// The pencil reports no pose unless it's hovering in range, so a squeeze made with the pencil
    /// held away from the screen has no roll to read. It should still behave predictably.
    func testUnknownRollFallsBackToDuration() {
        XCTAssertEqual(
            PencilSqueeze.outcome(duration: 0.2, rollDelta: nil, canLockAngle: true),
            .clearCanvas
        )
        XCTAssertEqual(
            PencilSqueeze.outcome(duration: 1.5, rollDelta: nil, canLockAngle: true),
            .releaseBrushAngleLock
        )
    }

    /// Below iOS 26 there is no API to pin an ink's angle, so there is no lock to set or release
    /// and every squeeze has to fall back to the action that does work.
    func testWithoutAngleLockingEverySqueezeClears() {
        for (duration, roll) in [(0.1, CGFloat(0)), (2.0, 0.9), (2.0, 0)] as [(TimeInterval, CGFloat)] {
            XCTAssertEqual(
                PencilSqueeze.outcome(duration: duration, rollDelta: roll, canLockAngle: false),
                .clearCanvas,
                "duration \(duration), roll \(roll)"
            )
        }
    }

    func testThresholdsAreSaneRelativeToEachOther() {
        XCTAssertGreaterThan(PencilSqueeze.clearMaxDuration, 0)
        XCTAssertLessThan(PencilSqueeze.clearMaxDuration, 1.0, "a quick press shouldn't need patience")
        XCTAssertGreaterThan(PencilSqueeze.rotationThreshold, 0)
        XCTAssertLessThan(PencilSqueeze.rotationThreshold, .pi / 8, "a lock shouldn't need a big twist")
    }
}
