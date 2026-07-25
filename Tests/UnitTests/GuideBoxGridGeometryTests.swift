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

        let size = GuideBoxGridGeometry.gridSize(units: units, maxBoxesPerRow: 6, availableWidth: 1000)
        let expectedBoxSize = GuideBoxGridGeometry.maxBoxSize
        let expectedWidth = expectedBoxSize * 3 + GuideBoxGridGeometry.interItemSpacing * 2

        XCTAssertEqual(size.width, expectedWidth)
        XCTAssertEqual(size.height, expectedBoxSize)
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
