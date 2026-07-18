import SwiftUI

struct SummaryView: View {
    let cardsWritten: Int
    let minutes: Int
    let againCount: Int
    let hardCount: Int
    let goodCount: Int
    let easyCount: Int
    let streakDays: Int
    let onBackToDecks: () -> Void
    let onStudyAnother: () -> Void

    @State private var discScale: CGFloat = 0.7
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            KakitoriTheme.paper.ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 24) {
                    discView
                    headlineView
                    summaryText
                    gradeGrid
                    streakLine
                }
                .frame(maxHeight: .infinity)
                .padding(.vertical, 32)

                buttonsView
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
        .accessibilityIdentifier("summary-done")
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                discScale = 1.0
            }
        }
    }

    private var discView: some View {
        Circle()
            .fill(KakitoriTheme.accent)
            .frame(width: 100, height: 100)
            .overlay(
                Text("済")
                    .font(KakitoriTheme.japaneseDisplayFontFixed(size: 60))
                    .foregroundStyle(KakitoriTheme.paper)
                    .accessibilityHidden(true)
            )
            .scaleEffect(discScale)
    }

    private var headlineView: some View {
        Text("お疲れさま！")
            .kakitoriFont(size: 34, weight: .bold)
            .foregroundStyle(KakitoriTheme.ink)
    }

    private var summaryText: some View {
        Text("Session complete — \(cardsWritten) cards written in \(minutes) min")
            .kakitoriFont(size: 16)
            .foregroundStyle(KakitoriTheme.ink)
            .multilineTextAlignment(.center)
    }

    private var gradeGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                GradeCard(count: againCount, label: "Again", isAccent: true)
                GradeCard(count: hardCount, label: "Hard", isAccent: false)
            }
            HStack(spacing: 16) {
                GradeCard(count: goodCount, label: "Good", isAccent: false)
                GradeCard(count: easyCount, label: "Easy", isAccent: false)
            }
        }
        .padding(.horizontal)
    }

    private var streakLine: some View {
        Text(isCompact ? "🔥 \(streakDays) day streak" : "🔥 \(streakDays) day streak · keep it going tomorrow")
            .kakitoriFont(size: 16)
            .foregroundStyle(KakitoriTheme.ink)
            .multilineTextAlignment(.center)
    }

    private var buttonsView: some View {
        VStack(spacing: 12) {
            Button(action: onBackToDecks) {
                Text(isCompact ? "Study another script" : "Back to decks")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .kakitoriFont(size: 16, weight: .semibold)
                    .foregroundStyle(KakitoriTheme.paper)
                    .background(KakitoriTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityIdentifier("back-to-decks")

            Button(action: onStudyAnother) {
                Text(isCompact ? "Back home" : "Study another deck")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .kakitoriFont(size: 16, weight: .semibold)
                    .foregroundStyle(KakitoriTheme.ink)
                    .background(KakitoriTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KakitoriTheme.boxLine, lineWidth: 1)
                    )
            }
            .accessibilityIdentifier("study-another")
        }
    }
}

private struct GradeCard: View {
    let count: Int
    let label: String
    let isAccent: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(String(count))
                .kakitoriFont(size: 28, weight: .semibold)
                .foregroundStyle(isAccent ? KakitoriTheme.accent : KakitoriTheme.ink)

            Text(label)
                .kakitoriFont(size: 11, weight: .semibold)
                .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(KakitoriTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KakitoriTheme.boxLine, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(label)")
    }
}
