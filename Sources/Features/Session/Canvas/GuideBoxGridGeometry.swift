import CoreGraphics

/// Pure layout math for the guide-box grid, shared by `GuideBoxRow` (which renders it) and
/// `CanvasPaneView` (which sizes the writing surface to match it) so the two can never drift apart.
enum GuideBoxGridGeometry {
    /// Ceiling on a single box. Sized for iPad: with the canvas now getting the full width and
    /// everything below the prompt band, a 250pt cap left a small box marooned in a large empty
    /// area. Below the cap the box is bounded by the space it actually has, in both directions.
    static let maxBoxSize: CGFloat = 420
    static let horizontalInset: CGFloat = 20
    static let interItemSpacing: CGFloat = 1
    static let rowSpacing: CGFloat = 8

    /// Wraps units into rows of at most `maxBoxesPerRow` boxes, keeping inline units attached
    /// to the row they trail.
    static func rows(units: [SegmentedUnit], maxBoxesPerRow: Int) -> [[SegmentedUnit]] {
        var rows: [[SegmentedUnit]] = []
        var currentRow: [SegmentedUnit] = []
        var boxCount = 0

        for unit in units {
            switch unit {
            case .box:
                if boxCount >= maxBoxesPerRow, !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                    boxCount = 0
                }
                currentRow.append(unit)
                boxCount += 1

            case .inline:
                currentRow.append(unit)
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    /// The side length of every box/inline unit in a row, given how many boxes share that row.
    ///
    /// Bounded by three things: the width its own row has to fit into, the height all `rowCount`
    /// rows have to share, and `maxBoxSize`. The height bound is what lets a box grow into a tall
    /// canvas area instead of staying at whatever the width alone allowed — pass `.infinity` (the
    /// default) where the caller genuinely has unlimited height.
    static func boxSize(
        forRowBoxCount rowBoxCount: Int,
        availableWidth: CGFloat,
        availableHeight: CGFloat = .infinity,
        rowCount: Int = 1
    ) -> CGFloat {
        let rows = CGFloat(max(1, rowCount))
        let widthBound = (availableWidth - horizontalInset) / CGFloat(max(1, rowBoxCount))
        let heightBound = (availableHeight - rowSpacing * (rows - 1)) / rows

        return min(maxBoxSize, widthBound, heightBound)
    }

    /// The bounding size of the rendered, centred guide-box grid — used to size the writing
    /// canvas so its drawable rect coincides with the visible box(es).
    static func gridSize(
        units: [SegmentedUnit],
        maxBoxesPerRow: Int,
        availableWidth: CGFloat,
        availableHeight: CGFloat = .infinity
    ) -> CGSize {
        let wrappedRows = rows(units: units, maxBoxesPerRow: maxBoxesPerRow)
        guard !wrappedRows.isEmpty else { return .zero }

        var maxRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for row in wrappedRows {
            let rowBoxCount = row.reduce(0) { count, unit in
                if case .box = unit {
                    return count + 1
                }
                return count
            }
            let size = boxSize(
                forRowBoxCount: rowBoxCount,
                availableWidth: availableWidth,
                availableHeight: availableHeight,
                rowCount: wrappedRows.count
            )
            let rowWidth = CGFloat(row.count) * size + CGFloat(max(0, row.count - 1)) * interItemSpacing
            maxRowWidth = max(maxRowWidth, rowWidth)
            totalHeight += size
        }

        totalHeight += CGFloat(max(0, wrappedRows.count - 1)) * rowSpacing

        return CGSize(width: maxRowWidth, height: totalHeight)
    }
}
