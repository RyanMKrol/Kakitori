import SwiftUI

struct GuideBoxRow: View {
    let units: [SegmentedUnit]
    let maxBoxesPerRow: Int
    let traceGlyphsVisible: Bool

    init(units: [SegmentedUnit], maxBoxesPerRow: Int = 6, traceGlyphsVisible: Bool = false) {
        self.units = units
        self.maxBoxesPerRow = maxBoxesPerRow
        self.traceGlyphsVisible = traceGlyphsVisible
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            GeometryReader { geometry in
                let wrappedRows = indexedRows()

                VStack(alignment: .center, spacing: 8) {
                    ForEach(0 ..< wrappedRows.count, id: \.self) { rowIndex in
                        let row = wrappedRows[rowIndex]
                        let rowBoxCount = row.reduce(0) { count, item in
                            if case .box = item.1 {
                                return count + 1
                            }
                            return count
                        }
                        let boxSize = GuideBoxGridGeometry.boxSize(
                            forRowBoxCount: rowBoxCount,
                            availableWidth: geometry.size.width
                        )

                        HStack(spacing: GuideBoxGridGeometry.interItemSpacing) {
                            ForEach(0 ..< row.count, id: \.self) { unitIndex in
                                let (globalIndex, unit) = row[unitIndex]

                                switch unit {
                                case let .box(glyph):
                                    GuideBox(traceGlyph: traceGlyphsVisible ? glyph : nil)
                                        .frame(height: boxSize)
                                        .accessibilityIdentifier("guide-box-\(globalIndex)")

                                case let .inline(text):
                                    Text(text)
                                        .font(KakitoriTheme.japaneseDisplayFontFixed(size: Swift.max(
                                            12,
                                            boxSize * 0.6
                                        )))
                                        .foregroundStyle(KakitoriTheme.ink)
                                        .lineLimit(1)
                                        .frame(height: boxSize, alignment: .center)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .accessibilityIdentifier("guide-box-row")
    }

    /// `GuideBoxGridGeometry.rows(units:maxBoxesPerRow:)`, re-paired with each unit's original
    /// index in `units` (used for the `guide-box-<index>` accessibility identifiers).
    private func indexedRows() -> [[(Int, SegmentedUnit)]] {
        let wrappedRows = GuideBoxGridGeometry.rows(units: units, maxBoxesPerRow: maxBoxesPerRow)
        var globalIndex = 0

        return wrappedRows.map { row in
            row.map { unit in
                defer { globalIndex += 1 }
                return (globalIndex, unit)
            }
        }
    }
}

#Preview("Guide Box Row - Regular (6 per row)") {
    let units = TargetSegmenter.segment("おはようございます。")

    VStack(spacing: 24) {
        GuideBoxRow(units: units, maxBoxesPerRow: 6)
            .padding()
    }
    .background(KakitoriTheme.paper)
}

#Preview("Guide Box Row - Compact (4 per row)") {
    let units = TargetSegmenter.segment("おはようございます。")

    VStack(spacing: 24) {
        GuideBoxRow(units: units, maxBoxesPerRow: 4)
            .padding()
    }
    .background(KakitoriTheme.paper)
    .frame(maxWidth: 390)
}
