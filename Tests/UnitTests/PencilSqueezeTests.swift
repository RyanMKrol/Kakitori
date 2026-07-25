@testable import Kakitori
import XCTest

/// The squeeze gesture itself only exists on Pencil Pro hardware, which no simulator can produce —
/// so what's pinned down here is the decision it feeds. Getting it wrong wipes someone's writing
/// when they meant to open the menu.
final class PencilSqueezeTests: XCTestCase {
    func testQuickSqueezeClearsTheCanvas() {
        XCTAssertEqual(
            PencilSqueeze.outcome(duration: 0.15, canLockAngle: true),
            .clearCanvas
        )
    }

    func testHoldingOpensTheBrushMenu() {
        XCTAssertEqual(
            PencilSqueeze.outcome(duration: 0.9, canLockAngle: true),
            .showBrushMenu
        )
    }

    func testTheBoundaryBelongsToTheMenu() {
        XCTAssertEqual(
            PencilSqueeze.outcome(duration: PencilSqueeze.clearMaxDuration, canLockAngle: true),
            .showBrushMenu,
            "a squeeze exactly at the threshold shouldn't wipe the canvas"
        )
    }

    /// Below iOS 26 there is no API to pin an ink's angle, so the menu has nothing the buttons
    /// don't already offer and every squeeze falls back to the action that does work.
    func testWithoutAngleLockingEverySqueezeClears() {
        for duration in [0.05, 0.39, 0.4, 3.0] {
            XCTAssertEqual(
                PencilSqueeze.outcome(duration: duration, canLockAngle: false),
                .clearCanvas,
                "duration \(duration)"
            )
        }
    }

    func testTheQuickPressThresholdIsQuick() {
        XCTAssertGreaterThan(PencilSqueeze.clearMaxDuration, 0)
        XCTAssertLessThan(PencilSqueeze.clearMaxDuration, 1.0, "a quick press shouldn't need patience")
    }
}
