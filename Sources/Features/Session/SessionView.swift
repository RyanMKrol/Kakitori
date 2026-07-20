import SwiftUI

@MainActor
struct SessionView: View {
    let viewModel: SessionViewModel
    let onClose: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            KakitoriTheme.paper.ignoresSafeArea()

            if isCompact {
                compactLayout
            } else {
                regularLayout
            }
        }
    }

    /// Regular (iPad / regular width): side-by-side prompt pane + canvas/action column.
    private var regularLayout: some View {
        VStack(spacing: 0) {
            topBar
                .frame(height: 60)
                .overlay(alignment: .bottom) {
                    Divider().background(KakitoriTheme.boxLine)
                }

            HStack(spacing: 0) {
                promptPane
                    .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    canvasPane
                        .frame(maxHeight: .infinity)

                    actionRow
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// Compact (iPhone / portrait, docs/06 §2.3): prompt band above the canvas, actions pinned bottom.
    private var compactLayout: some View {
        VStack(spacing: 0) {
            topBar
                .frame(height: 60)
                .overlay(alignment: .bottom) {
                    Divider().background(KakitoriTheme.boxLine)
                }

            promptPane
                .frame(height: 280)
                .overlay(alignment: .bottom) {
                    Divider().background(KakitoriTheme.boxLine)
                }

            canvasPane
                .frame(maxHeight: .infinity)

            actionRow
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(KakitoriTheme.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityIdentifier("session-close")

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.deckName)
                    .kakitoriFont(size: 12, weight: .bold)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(viewModel.mode.glyph)
                        .kakitoriFont(size: 11)
                        .accessibilityHidden(true)
                    Text("·")
                        .kakitoriFont(size: 11)
                    Text(viewModel.mode.label)
                        .kakitoriFont(size: 11)
                }
                .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
            }

            Spacer()

            VStack(spacing: 4) {
                progressBar
                Text("\(done) done · \(left) left")
                    .kakitoriFont(size: 10, weight: .semibold)
                    .foregroundStyle(KakitoriTheme.ink)
            }
            .frame(maxWidth: 120)

            Spacer()

            HStack(spacing: 8) {
                chip(
                    count: viewModel.newCount,
                    label: "new",
                    foreground: KakitoriTheme.chipNewForeground,
                    background: KakitoriTheme.chipNewBackground
                )
                chip(
                    count: viewModel.learnCount,
                    label: "learn",
                    foreground: KakitoriTheme.chipLearnForeground,
                    background: KakitoriTheme.chipLearnBackground
                )
                chip(
                    count: viewModel.dueCount,
                    label: "due",
                    foreground: KakitoriTheme.chipDueForeground,
                    background: KakitoriTheme.chipDueBackground
                )
            }
            .frame(maxWidth: 140)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// Progress reflects cards COMPLETED (graduated out of learning), not grade attempts — so it
    /// never advances on "Again" and, against a fixed session-size denominator, is monotonic. (T077)
    private var done: Int {
        viewModel.completedCount
    }

    private var left: Int {
        max(0, viewModel.sessionCardCount - viewModel.completedCount)
    }

    private var progressBar: some View {
        let denominator = viewModel.sessionCardCount
        let progress = denominator > 0
            ? min(1, max(0, Double(viewModel.completedCount) / Double(denominator)))
            : 0

        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(KakitoriTheme.boxLine)

                RoundedRectangle(cornerRadius: 4)
                    .fill(KakitoriTheme.accent)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 6)
    }

    /// Compact drops the word labels and shows bare numbers (docs/06 §2.3); regular keeps "N new" etc.
    private func chip(count: Int, label: String, foreground: Color, background: Color) -> some View {
        Text(isCompact ? "\(count)" : "\(count) \(label)")
            .kakitoriFont(size: 11, weight: .semibold)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .cornerRadius(12)
    }

    // MARK: - Panes

    private var promptPane: some View {
        PromptPaneView(viewModel: viewModel)
    }

    private var canvasPane: some View {
        CanvasPaneView(viewModel: viewModel)
    }

    private var actionRow: some View {
        ActionRowView(viewModel: viewModel)
    }
}

// MARK: - Preview

#Preview {
    Text("SessionView preview not available")
}
