import SwiftUI

@MainActor
struct CanvasPaneView: View {
    let viewModel: SessionViewModel

    @State private var controller = WritingCanvasController()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            topRow

            GeometryReader { geometry in
                let gridSize = GuideBoxGridGeometry.gridSize(
                    units: segmentedUnits,
                    maxBoxesPerRow: maxBoxesPerRow,
                    availableWidth: geometry.size.width,
                    availableHeight: geometry.size.height
                )

                ZStack {
                    TraceGuideLayer(
                        units: segmentedUnits,
                        maxBoxesPerRow: maxBoxesPerRow,
                        isVisible: viewModel.presentedMode == .trace
                    )
                    WritingCanvas(controller: controller, colorScheme: colorScheme)
                        .frame(
                            width: gridSize.width > 0 ? gridSize.width : nil,
                            height: gridSize.height > 0 ? gridSize.height : nil
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityAction(named: "Show answer") {
                viewModel.showAnswer()
            }
        }
        .padding(16)
        // Keyed on `presentationCount`, NOT the note id: when the last card in the queue is graded
        // "Again" it comes straight back as the same note, so an id-keyed task never re-fires and the
        // card would return silently, with the previous attempt still on the canvas.
        .task(id: viewModel.presentationCount) {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms post-appearance settle
            viewModel.triggerAutoplayOnCardAppearance()
        }
        .onChange(of: viewModel.presentationCount) {
            controller.clear()
        }
    }

    private var segmentedUnits: [SegmentedUnit] {
        guard let target = viewModel.currentNote?.target else { return [] }
        return TargetSegmenter.segment(target)
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var maxBoxesPerRow: Int {
        isCompact ? 4 : 6
    }

    private var hint: String {
        switch viewModel.presentedMode {
        case .trace:
            "Trace each character in its box"
        case .listen:
            "Write the word you heard"
        case .translate:
            "Write the Japanese here"
        default:
            ""
        }
    }

    /// The hint labels the canvas, so it sits centred over it on iPad rather than pinned to the far
    /// left with the buttons pinned to the far right — across a full-width iPad that reads as two
    /// unrelated things at opposite corners. Compact keeps them in a row; there isn't the width to
    /// centre the hint without it running into the buttons.
    private var topRow: some View {
        ZStack(alignment: .top) {
            if !isCompact {
                hintLabel
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }

            HStack(alignment: .top) {
                if isCompact {
                    hintLabel
                }

                Spacer()

                HStack(spacing: 8) {
                    pillButton(title: "↶ Undo", identifier: "canvas-undo") {
                        controller.undo()
                    }

                    pillButton(title: "Clear", identifier: "canvas-clear") {
                        controller.clear()
                    }
                }
            }
        }
    }

    private var hintLabel: some View {
        Text(hint)
            .kakitoriFont(size: 13)
            .foregroundStyle(KakitoriTheme.ink.opacity(0.5))
            .accessibilityIdentifier("canvas-hint")
    }

    private func pillButton(title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .kakitoriFont(size: 13, weight: .semibold)
                .foregroundStyle(KakitoriTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(KakitoriTheme.paper)
                .overlay(
                    Capsule()
                        .stroke(KakitoriTheme.boxLine, lineWidth: 1)
                )
                .clipShape(Capsule())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    Text("CanvasPaneView preview not available")
}
