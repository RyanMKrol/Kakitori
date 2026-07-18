import SwiftUI

@MainActor
struct SessionView: View {
    let viewModel: SessionViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            KakitoriTheme.paper.ignoresSafeArea()

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
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(viewModel.mode.glyph)
                        .font(.system(size: 11))
                    Text("·")
                        .font(.system(size: 11))
                    Text(viewModel.mode.label)
                        .font(.system(size: 11))
                }
                .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
            }

            Spacer()

            VStack(spacing: 4) {
                progressBar
                Text("\(done) done · \(left) left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(KakitoriTheme.ink)
            }
            .frame(maxWidth: 120)

            Spacer()

            HStack(spacing: 8) {
                chipNew
                chipLearn
                chipDue
            }
            .frame(maxWidth: 140)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var done: Int {
        viewModel.gradeCounts.values.reduce(0, +)
    }

    private var left: Int {
        viewModel.newCount + viewModel.learnCount + viewModel.dueCount
    }

    private var progressBar: some View {
        let total = done + left
        let progress = total > 0 ? Double(done) / Double(total) : 0

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

    private var chipNew: some View {
        Text("\(viewModel.newCount) new")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(KakitoriTheme.chipNewForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(KakitoriTheme.chipNewBackground)
            .cornerRadius(12)
    }

    private var chipLearn: some View {
        Text("\(viewModel.learnCount) learn")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(KakitoriTheme.chipLearnForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(KakitoriTheme.chipLearnBackground)
            .cornerRadius(12)
    }

    private var chipDue: some View {
        Text("\(viewModel.dueCount) due")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(KakitoriTheme.chipDueForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(KakitoriTheme.chipDueBackground)
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
