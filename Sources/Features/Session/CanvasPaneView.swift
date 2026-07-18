import SwiftUI

@MainActor
struct CanvasPaneView: View {
    let viewModel: SessionViewModel

    @State private var controller = WritingCanvasController()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 12) {
            topRow

            ZStack {
                TraceGuideLayer(
                    units: segmentedUnits,
                    maxBoxesPerRow: horizontalSizeClass == .compact ? 4 : 6,
                    isVisible: viewModel.mode == .trace
                )
                WritingCanvas(controller: controller)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityAction(named: "Show answer") {
                viewModel.showAnswer()
            }
        }
        .padding(16)
        .onChange(of: viewModel.currentNote?.id) {
            controller.clear()
        }
    }

    private var segmentedUnits: [SegmentedUnit] {
        guard let target = viewModel.currentNote?.target else { return [] }
        return TargetSegmenter.segment(target)
    }

    private var hint: String {
        switch viewModel.mode {
        case .trace:
            "Trace each character in its box"
        case .listen:
            "Write the word you heard"
        case .translate:
            "Write the Japanese here"
        case .recall:
            "Write the word from memory"
        default:
            ""
        }
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            Text(hint)
                .kakitoriFont(size: 13)
                .foregroundStyle(KakitoriTheme.ink.opacity(0.5))
                .accessibilityIdentifier("canvas-hint")

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
