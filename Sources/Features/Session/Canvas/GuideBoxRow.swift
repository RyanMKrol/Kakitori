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
                let wrappedRows = layoutRows(width: geometry.size.width)

                VStack(alignment: .center, spacing: 8) {
                    ForEach(0 ..< wrappedRows.count, id: \.self) { rowIndex in
                        let row = wrappedRows[rowIndex]
                        let rowBoxCount = row.reduce(0) { count, item in
                            if case .box = item.1 {
                                return count + 1
                            }
                            return count
                        }
                        let boxSize = Swift.min(160, (geometry.size.width - 40) / CGFloat(Swift.max(1, rowBoxCount)))

                        HStack(spacing: 4) {
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

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .accessibilityIdentifier("guide-box-row")
    }

    private func layoutRows(width _: CGFloat) -> [[(Int, SegmentedUnit)]] {
        var rows: [[(Int, SegmentedUnit)]] = []
        var currentRow: [(Int, SegmentedUnit)] = []
        var boxCount = 0

        for (index, unit) in units.enumerated() {
            switch unit {
            case .box:
                if boxCount >= maxBoxesPerRow, !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                    boxCount = 0
                }
                currentRow.append((index, unit))
                boxCount += 1

            case .inline:
                currentRow.append((index, unit))
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
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
