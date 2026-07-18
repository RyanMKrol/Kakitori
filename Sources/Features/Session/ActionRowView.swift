import SwiftUI

@MainActor
struct ActionRowView: View {
    let viewModel: SessionViewModel

    var body: some View {
        if viewModel.phase == .revealed {
            gradeRow
                .transition(.scale.combined(with: .opacity))
        } else {
            showAnswerButton
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var showAnswerButton: some View {
        Button(action: { viewModel.showAnswer() }, label: {
            Text("Show answer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KakitoriTheme.paper)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(KakitoriTheme.ink)
                .cornerRadius(14)
        })
        .accessibilityIdentifier("show-answer")
        .padding(16)
    }

    private var gradeRow: some View {
        HStack(spacing: 8) {
            gradeButton(grade: .again, label: "Again")
            gradeButton(grade: .hard, label: "Hard")
            gradeButton(grade: .good, label: "Good")
            gradeButton(grade: .easy, label: "Easy")
        }
        .padding(16)
    }

    private func gradeButton(grade: Grade, label: String) -> some View {
        let preview = viewModel.gradePreviews[grade]
        let isAgain = grade == .again
        let isEasy = grade == .easy

        return Button(action: { viewModel.grade(grade) }, label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                if let preview {
                    Text(preview.label)
                        .font(.system(size: 11, weight: .regular))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(isEasy ? KakitoriTheme.paper : KakitoriTheme.ink)
            .background(
                isAgain ? KakitoriTheme.accent :
                    isEasy ? KakitoriTheme.ink :
                    KakitoriTheme.paper
            )
            .overlay(
                !isAgain && !isEasy ? RoundedRectangle(cornerRadius: 8)
                    .stroke(KakitoriTheme.boxLine, lineWidth: 1) : nil
            )
            .cornerRadius(8)
        })
        .accessibilityIdentifier("grade-\(grade.rawValue)")
    }
}

#Preview {
    Text("ActionRowView preview not available")
}
