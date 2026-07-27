import SwiftUI

@MainActor
struct PromptPaneView: View {
    let viewModel: SessionViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Compact renders the prompt as a condensed band above the canvas (docs/06 §2.3): one sub-line,
    /// tighter padding, a smaller answer glyph — same copy, restyled.
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var promptPadding: CGFloat {
        isCompact ? 20 : 32
    }

    private var subLineLimit: Int {
        isCompact ? 1 : 3
    }

    /// The prompt band spans the full width on iPad now, and a line of body copy stretched across
    /// 1100 points is unreadable — so the content sits in a measured column, centred in the band.
    private var promptContentWidth: CGFloat {
        isCompact ? .infinity : 620
    }

    /// A band this short can't stack ANSWER's glyph, reading, meaning and audio button on top of
    /// each other without running out of room — iPad in landscape is the case that forces it.
    private static let tightBandHeight: CGFloat = 330

    var body: some View {
        GeometryReader { geometry in
            let isTight = !isCompact && geometry.size.height < Self.tightBandHeight

            ZStack {
                KakitoriTheme.paper

                // The prompt stays fully rendered and OPAQUE underneath the whole time; only the
                // answer's opacity animates on top. Because there is always a fully-opaque foreground
                // layer over the paper, the background never bleeds through the reveal crossfade — no
                // flash. This is a pure opacity change (no scale/slide), so Reduce Motion is honored.
                promptView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KakitoriTheme.paper)
                    .accessibilityHidden(viewModel.phase == .revealed)

                // A view at opacity 0 still takes taps, and this one covers the whole pane — so hit
                // testing follows the visible layer, or the invisible answer block would swallow taps
                // meant for the prompt (Listen mode's replay button sits right under it).
                answerBlock(isTight: isTight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KakitoriTheme.paper)
                    .opacity(viewModel.phase == .revealed ? 1 : 0)
                    .allowsHitTesting(viewModel.phase == .revealed)
                    .accessibilityHidden(viewModel.phase != .revealed)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        }
    }

    @ViewBuilder
    private var promptView: some View {
        // `presentedMode`, NOT `mode`: `mode` is the session-level pick, which is `.mixed` for a
        // mixed session and would fall through to the trace prompt on every card. The resolved
        // per-card mode is what the user is actually being asked to do.
        switch viewModel.presentedMode {
        case .listen:
            listenModePrompt
        case .translate:
            translateModePrompt
        default:
            traceModePrompt
        }
    }

    private var traceModePrompt: some View {
        VStack(spacing: 12) {
            Text("TRACE MODE")
                .kakitoriFont(size: 12, weight: .semibold)
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            Text("Write over the faded guides")
                .kakitoriFont(size: 22, weight: .bold)
                .foregroundStyle(KakitoriTheme.ink)

            Text("Follow the light strokes in each box. Aim for balance and correct stroke order.")
                .kakitoriFont(size: 15)
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(subLineLimit)
                .multilineTextAlignment(.center)

            if let reading = viewModel.currentNote?.pronunciation {
                Text(reading)
                    .font(KakitoriTheme.japaneseDisplayFont(size: 18))
                    .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
            }
        }
        .frame(maxWidth: promptContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(promptPadding)
    }

    private var listenModePrompt: some View {
        VStack(spacing: 12) {
            Text("LISTEN & WRITE")
                .kakitoriFont(size: 12, weight: .semibold)
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
                .kakitoriFont(size: 15)
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(subLineLimit)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: promptContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(promptPadding)
    }

    private var translateModePrompt: some View {
        VStack(spacing: 12) {
            Text("TRANSLATE & WRITE")
                .kakitoriFont(size: 12, weight: .semibold)
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            Text("English")
                .kakitoriFont(size: 13)
                .foregroundStyle(KakitoriTheme.ink.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.currentNote?.english ?? "")
                .kakitoriFont(size: 34, weight: .bold)
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Write this in Japanese.")
                .kakitoriFont(size: 15)
                .foregroundStyle(KakitoriTheme.ink)
                .lineLimit(isCompact ? 1 : 2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The copy stays left-aligned (it's a sentence to read), but the block is centred in the
        // band — full-width English ragging across an iPad reads as a stray paragraph.
        .frame(maxWidth: promptContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(promptPadding)
    }

    /// The revealed answer, laid out to match where the prompt it replaces sat: top of the band,
    /// centred. `isTight` swings it from a single column to glyph-beside-details, which is what
    /// fits when the band is wide and short.
    private func answerBlock(isTight: Bool) -> some View {
        VStack(spacing: isTight ? 8 : 16) {
            Text("ANSWER")
                .kakitoriFont(size: 12, weight: .semibold)
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            if isTight {
                HStack(alignment: .center, spacing: 28) {
                    answerTargetComparison
                    VStack(alignment: .leading, spacing: 10) {
                        answerDetails(alignment: .leading)
                    }
                }
            } else {
                answerTargetComparison
                answerDetails(alignment: .center)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(promptPadding)
        .accessibilityIdentifier("answer-block")
    }

    /// `revealedNote`, NOT `currentNote`: grading advances the card and starts the answer's
    /// fade-out in the same beat, so a block bound to `currentNote` would swap in the NEXT
    /// card's answer while still on screen. `revealedNote` holds the answer being dismissed
    /// until the next reveal, so nothing new renders here until the block is invisible.
    private var revealedNote: Note? {
        viewModel.revealedNote
    }

    /// The answer glyph, rendered once per candidate typeface so the faces can be compared on the
    /// character actually being practised rather than on a specimen sheet. Temporary: once a face
    /// is chosen this collapses back to a single glyph.
    @ViewBuilder
    private var answerTargetComparison: some View {
        if let target = revealedNote?.target {
            let unitCount = revealedNote?.units.count ?? 1
            let fontSize = comparisonFontSize(unitCount: unitCount)

            // Always side by side, including on the phone: the whole point is judging the three
            // against each other, and stacked samples can't be compared without scrolling.
            HStack(alignment: .top, spacing: isCompact ? 8 : 20) {
                ForEach(PracticeFont.allCases) { face in
                    VStack(spacing: 4) {
                        Text(target)
                            .font(face.fixedFont(size: fontSize, bold: true))
                            .foregroundStyle(KakitoriTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .accessibilityIdentifier("answer-target-\(face.rawValue)")

                        Text(face.displayName)
                            .kakitoriFont(size: isCompact ? 10 : 11, weight: .semibold)
                            .foregroundStyle(KakitoriTheme.accent)
                            .multilineTextAlignment(.center)

                        // Says so rather than quietly rendering a substitute — two options showing
                        // the same fallback would otherwise look like a tie between real choices.
                        Text(face.isAvailable ? face.summary : "Not on this device — showing a substitute")
                            .kakitoriFont(size: isCompact ? 9 : 10)
                            .foregroundStyle(KakitoriTheme.ink.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Three glyphs share the width one used to have, so they're sized down from the single-glyph
    /// sizes — still big enough to judge stroke shapes, which is the point of the comparison.
    private func comparisonFontSize(unitCount: Int) -> CGFloat {
        if isCompact { return unitCount <= 2 ? 40 : 30 }
        return unitCount <= 2 ? 72 : 48
    }

    @ViewBuilder
    private func answerDetails(alignment: HorizontalAlignment) -> some View {
        let textAlignment: TextAlignment = alignment == .leading ? .leading : .center
        let frameAlignment: Alignment = alignment == .leading ? .leading : .center

        if let reading = revealedNote?.pronunciation {
            Text(reading)
                .font(KakitoriTheme.japaneseDisplayFont(size: 22, bold: true))
                .foregroundStyle(KakitoriTheme.accent)
        }

        if let english = revealedNote?.english {
            Text(english)
                .kakitoriFont(size: 17)
                .foregroundStyle(KakitoriTheme.ink)
                .multilineTextAlignment(textAlignment)
        }

        if let hint = revealedNote?.hint, !hint.isEmpty {
            Text(hint)
                .kakitoriFont(size: 15)
                .foregroundStyle(KakitoriTheme.ink)
                .multilineTextAlignment(textAlignment)
                .padding(12)
                .frame(maxWidth: 420, alignment: frameAlignment)
                .background(KakitoriTheme.paper.opacity(0.8))
                .cornerRadius(16)
        }

        Button(
            action: { viewModel.replayAudio() },
            label: {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                    Text("Play audio")
                }
                .kakitoriFont(size: 15, weight: .semibold)
                .foregroundStyle(KakitoriTheme.paper)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(KakitoriTheme.accent)
                .cornerRadius(20)
            }
        )
        .accessibilityIdentifier("play-audio-answer")
        .padding(.top, 4)
    }
}

#Preview {
    Text("PromptPaneView preview")
}
