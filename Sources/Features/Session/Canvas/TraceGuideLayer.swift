import SwiftUI

/// Renders faded glyph guides under the canvas in a ZStack.
///
/// Intended composition:
/// ```swift
/// ZStack {
///     TraceGuideLayer(units: [...], isVisible: true)
///     WritingCanvas(...)
/// }
/// ```
///
/// Guides sit behind strokes; only Trace mode shows glyphs. Clear (PKDrawing only)
/// cannot erase guides since they are a SwiftUI layer, not part of the canvas.
struct TraceGuideLayer: View {
    let units: [SegmentedUnit]
    let maxBoxesPerRow: Int
    let isVisible: Bool

    init(units: [SegmentedUnit], maxBoxesPerRow: Int = 6, isVisible: Bool) {
        self.units = units
        self.maxBoxesPerRow = maxBoxesPerRow
        self.isVisible = isVisible
    }

    var body: some View {
        GuideBoxRow(units: units, maxBoxesPerRow: maxBoxesPerRow, traceGlyphsVisible: isVisible)
            .accessibilityIdentifier("trace-guide-layer")
    }
}

#Preview("Trace Guide Layer - Visible") {
    let units = TargetSegmenter.segment("ありがとう")

    ZStack {
        TraceGuideLayer(units: units, isVisible: true)
        WritingCanvas(controller: WritingCanvasController())
    }
    .background(KakitoriTheme.paper)
}

#Preview("Trace Guide Layer - Hidden") {
    let units = TargetSegmenter.segment("ありがとう")

    ZStack {
        TraceGuideLayer(units: units, isVisible: false)
        WritingCanvas(controller: WritingCanvasController())
    }
    .background(KakitoriTheme.paper)
}
