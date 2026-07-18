import SwiftUI

@MainActor
struct PromptPaneView: View {
    let viewModel: SessionViewModel

    var body: some View {
        ZStack {
            KakitoriTheme.paper

            if viewModel.phase == .prompt {
                promptView
                    .transition(.opacity)
            } else {
                answerBlock
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
    }

    @ViewBuilder
    private var promptView: some View {
        switch viewModel.mode {
        case .listen:
            listenModePrompt
        case .translate:
            translateModePrompt
        case .recall:
            recallModePrompt
        default:
            traceModePrompt
        }
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

    private var listenModePrompt: some View {
        VStack(spacing: 12) {
            Text("LISTEN & WRITE")
                .font(KakitoriTheme.smallCapsLabel(size: 12))
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            Button(
                action: { viewModel.replayAudio() },
                label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(KakitoriTheme.accent)
                }
            )
            .accessibilityIdentifier("play-audio")

            Text("Tap to hear it again, then write what you hear.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var translateModePrompt: some View {
        VStack(spacing: 12) {
            Text("TRANSLATE & WRITE")
                .font(KakitoriTheme.smallCapsLabel(size: 12))
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            Text("English")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(KakitoriTheme.ink.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.currentNote?.english ?? "")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Write this in Japanese.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
    }

    private var recallModePrompt: some View {
        let showRomaji = (UserDefaults.standard.object(forKey: "showRomaji") as? Bool) ?? true
        let hasEnglish = viewModel.currentNote?.english != nil && !(viewModel.currentNote?.english?.isEmpty ?? true)
        let shouldShowReading = showRomaji || !hasEnglish

        return VStack(spacing: 12) {
            Text("RECALL MODE")
                .font(KakitoriTheme.smallCapsLabel(size: 12))
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            if shouldShowReading {
                Text("Reading")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(KakitoriTheme.ink.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let pronunciation = viewModel.currentNote?.pronunciation {
                    Text(pronunciation)
                        .font(KakitoriTheme.japaneseDisplayFont(size: 40))
                        .foregroundStyle(KakitoriTheme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if hasEnglish, let english = viewModel.currentNote?.english {
                Text("\u{201C}\(english)\u{201D}")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(KakitoriTheme.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Write the word from memory.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

            Button(
                action: { viewModel.replayAudio() },
                label: {
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
                }
            )
            .accessibilityIdentifier("play-audio-answer")

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
