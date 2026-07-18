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
                    .font(KakitoriTheme.japaneseDisplayFont(size: 60))
                    .foregroundStyle(KakitoriTheme.paper)
            )
            .scaleEffect(discScale)
    }

    private var headlineView: some View {
        Text("お疲れさま！")
            .font(.system(size: 34, weight: .bold, design: .default))
            .foregroundStyle(KakitoriTheme.ink)
    }

    private var summaryText: some View {
        Text("Session complete — \(cardsWritten) cards written in \(minutes) min")
            .font(.system(size: 16, weight: .regular, design: .default))
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
        Text("🔥 \(streakDays) day streak · keep it going tomorrow")
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(KakitoriTheme.ink)
            .multilineTextAlignment(.center)
    }

    private var buttonsView: some View {
        VStack(spacing: 12) {
            Button(action: onBackToDecks) {
                Text("Back to decks")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(KakitoriTheme.paper)
                    .background(KakitoriTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityIdentifier("back-to-decks")

            Button(action: onStudyAnother) {
                Text("Study another deck")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(KakitoriTheme.ink)
                    .background(Color.white)
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
                .font(.system(size: 28, weight: .semibold, design: .default))
                .foregroundStyle(isAccent ? KakitoriTheme.accent : KakitoriTheme.ink)

            Text(label)
                .font(KakitoriTheme.smallCapsLabel(size: 11))
                .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KakitoriTheme.boxLine, lineWidth: 1)
        )
    }
}
