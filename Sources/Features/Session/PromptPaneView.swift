import SwiftUI

@MainActor
struct PromptPaneView: View {
    let viewModel: SessionViewModel

    var body: some View {
        ZStack {
            KakitoriTheme.paper

            if viewModel.phase == .prompt {
                traceModePrompt
                    .transition(.opacity)
            } else {
                answerBlock
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
    }

    private var traceModePrompt: some View {
        VStack(spacing: 12) {
            Text("TRACE MODE")
                .font(KakitoriTheme.smallCapsLabel(size: 12))
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            Text("Write over the faded guides")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(KakitoriTheme.ink)

            Text("Follow the light strokes in each box. Aim for balance and correct stroke order.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(3)
                .multilineTextAlignment(.center)

            if let reading = viewModel.currentNote?.pronunciation {
                Text(reading)
                    .font(KakitoriTheme.japaneseDisplayFont(size: 18))
                    .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var answerBlock: some View {
        VStack(spacing: 16) {
            Text("ANSWER")
                .font(KakitoriTheme.smallCapsLabel(size: 12))
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            let unitCount = viewModel.currentNote?.units.count ?? 1
            let fontSize: CGFloat = unitCount <= 2 ? 96 : 64

            if let target = viewModel.currentNote?.target {
                Text(target)
                    .font(KakitoriTheme.japaneseDisplayFont(size: fontSize, bold: true))
                    .foregroundStyle(KakitoriTheme.ink)
            }

            if let reading = viewModel.currentNote?.pronunciation {
                Text(reading)
                    .font(KakitoriTheme.japaneseDisplayFont(size: 22, bold: true))
                    .foregroundStyle(KakitoriTheme.accent)
            }

            if let english = viewModel.currentNote?.english {
                Text(english)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(KakitoriTheme.ink)
            }

            if let hint = viewModel.currentNote?.hint, !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(KakitoriTheme.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(KakitoriTheme.paper.opacity(0.8))
                    .cornerRadius(16)
            }

            Spacer()
                .frame(height: 8)

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2")
                Text("Play audio")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(KakitoriTheme.paper)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(KakitoriTheme.accent)
            .cornerRadius(20)
            .onTapGesture {}
            .allowsHitTesting(false)
            // TODO: Wire to Sources/Audio/AudioService.swift

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityIdentifier("answer-block")
    }
}

#Preview {
    Text("PromptPaneView preview")
}
