import CoreGraphics
@testable import Kakitori
import XCTest

final class GuideBoxGridGeometryTests: XCTestCase {
    func testSingleCharacterGridSizeIsOneBox() {
        let units: [SegmentedUnit] = [.box("あ")]

        let size = GuideBoxGridGeometry.gridSize(units: units, maxBoxesPerRow: 6, availableWidth: 1000)

        XCTAssertEqual(size.width, GuideBoxGridGeometry.maxBoxSize)
        XCTAssertEqual(size.height, GuideBoxGridGeometry.maxBoxSize)
    }

    func testMultiCharacterRowSumsWidthsAndSpacing() {
        let units: [SegmentedUnit] = [.box("あ"), .box("り"), .box("が")]
        let availableWidth: CGFloat = 1000

        let size = GuideBoxGridGeometry.gridSize(units: units, maxBoxesPerRow: 6, availableWidth: availableWidth)

        // Three boxes sharing 1000 points are bounded by the width they have to share, not the cap.
        let expectedBoxSize = (availableWidth - GuideBoxGridGeometry.horizontalInset) / 3
        XCTAssertLessThan(expectedBoxSize, GuideBoxGridGeometry.maxBoxSize)

        XCTAssertEqual(size.width, expectedBoxSize * 3 + GuideBoxGridGeometry.interItemSpacing * 2)
        XCTAssertEqual(size.height, expectedBoxSize)
    }

    /// The height bound is what lets a box grow into the canvas area rather than staying at
    /// whatever the width alone allowed — and what stops a tall grid overflowing a short one.
    func testShortPaneBoundsBoxesByHeight() {
        let units: [SegmentedUnit] = [.box("あ")]
        let availableHeight: CGFloat = 180

        let size = GuideBoxGridGeometry.gridSize(
            units: units,
            maxBoxesPerRow: 6,
            availableWidth: 1000,
            availableHeight: availableHeight
        )

        XCTAssertEqual(size.height, availableHeight, "a single box fills the height it is given")
        XCTAssertEqual(size.width, availableHeight, "boxes stay square")
        XCTAssertLessThan(size.height, GuideBoxGridGeometry.maxBoxSize)
    }

    func testTwoRowsShareTheAvailableHeight() {
        let units: [SegmentedUnit] = (0 ..< 8).map { .box("字\($0)") }
        let availableHeight: CGFloat = 400

        let size = GuideBoxGridGeometry.gridSize(
            units: units,
            maxBoxesPerRow: 6,
            availableWidth: 4000,
            availableHeight: availableHeight
        )

        XCTAssertEqual(size.height, availableHeight, accuracy: 0.001, "two rows plus their spacing fit exactly")
    }

    func testUnconstrainedHeightStillHonoursTheMaxBoxSize() {
        let units: [SegmentedUnit] = [.box("あ")]

        let size = GuideBoxGridGeometry.gridSize(units: units, maxBoxesPerRow: 6, availableWidth: 4000)

        XCTAssertEqual(size.height, GuideBoxGridGeometry.maxBoxSize)
    }

    func testWrappedMultiRowTargetStacksRowHeights() {
        let units: [SegmentedUnit] = (0 ..< 8).map { .box("字\($0)") }
        let availableWidth: CGFloat = 1000

        let size = GuideBoxGridGeometry.gridSize(units: units, maxBoxesPerRow: 6, availableWidth: availableWidth)
        let rows = GuideBoxGridGeometry.rows(units: units, maxBoxesPerRow: 6)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].count, 6)
        XCTAssertEqual(rows[1].count, 2)

        let boxSizeRow1 = GuideBoxGridGeometry.boxSize(forRowBoxCount: 6, availableWidth: availableWidth)
        let boxSizeRow2 = GuideBoxGridGeometry.boxSize(forRowBoxCount: 2, availableWidth: availableWidth)
        let expectedHeight = boxSizeRow1 + boxSizeRow2 + GuideBoxGridGeometry.rowSpacing
        XCTAssertEqual(size.height, expectedHeight)
    }

    func testNarrowPaneShrinksBoxesBelowMaxSize() {
        let units: [SegmentedUnit] = [.box("あ"), .box("り")]
        let availableWidth: CGFloat = 500

        let size = GuideBoxGridGeometry.gridSize(units: units, maxBoxesPerRow: 6, availableWidth: availableWidth)
        let expectedBoxSize = (availableWidth - GuideBoxGridGeometry.horizontalInset) / 2

        XCTAssertLessThan(expectedBoxSize, GuideBoxGridGeometry.maxBoxSize)
        XCTAssertEqual(size.width, expectedBoxSize * 2 + GuideBoxGridGeometry.interItemSpacing)
    }

    func testEmptyUnitsProduceZeroSize() {
        let size = GuideBoxGridGeometry.gridSize(units: [], maxBoxesPerRow: 6, availableWidth: 1000)

        XCTAssertEqual(size, .zero)
    }
}
