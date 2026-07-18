import SwiftUI

enum PracticeMode: String, CaseIterable {
    case trace
    case listen
    case translate
    case recall
    case mixed

    var glyph: String {
        switch self {
        case .trace: "書"
        case .listen: "聞"
        case .translate: "訳"
        case .recall: "思"
        case .mixed: "混"
        }
    }

    var label: String {
        switch self {
        case .trace: "Trace"
        case .listen: "Listen & Write"
        case .translate: "Translate & Write"
        case .recall: "Recall"
        case .mixed: "Mixed"
        }
    }

    var description: String {
        switch self {
        case .trace: "Write over a faded guide"
        case .listen: "Hear it, then write what you heard"
        case .translate: "See the English, write the Japanese"
        case .recall: "From the reading, write from memory"
        case .mixed: "Rotate through all four modes"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .trace: "mode-trace"
        case .listen: "mode-listen"
        case .translate: "mode-translate"
        case .recall: "mode-recall"
        case .mixed: "mode-mixed"
        }
    }
}

struct DeckSetupSheet: View {
    let jpTitle: String
    let enTitle: String
    let dueCount: Int
    let onStart: (PracticeMode) -> Void
    let onClose: () -> Void
    let availableModes: [PracticeMode]

    @State private var selectedMode: PracticeMode?

    init(
        jpTitle: String,
        enTitle: String,
        dueCount: Int,
        availableModes: [PracticeMode],
        onStart: @escaping (PracticeMode) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.jpTitle = jpTitle
        self.enTitle = enTitle
        self.dueCount = dueCount
        self.availableModes = availableModes
        self.onStart = onStart
        self.onClose = onClose
        _selectedMode = State(initialValue: availableModes.first)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBand

            VStack(spacing: 24) {
                modeCaption
                modeList
                Spacer()
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)

            startButton
        }
        .background(KakitoriTheme.paper)
    }

    private var headerBand: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(jpTitle)
                    .font(KakitoriTheme.japaneseDisplayFont(size: 28))
                    .foregroundStyle(KakitoriTheme.paper)

                Text("\(enTitle) · \(dueCount) cards due")
                    .font(.subheadline)
                    .foregroundStyle(KakitoriTheme.paper.opacity(0.8))
            }

            Spacer()

            Button(action: onClose) {
                Text("✕")
                    .font(.title2)
                    .foregroundStyle(KakitoriTheme.paper)
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("deck-setup-close")
        }
        .padding(20)
        .background(KakitoriTheme.ink)
    }

    private var modeCaption: some View {
        Text("PRACTICE MODE")
            .kakitoriFont(size: 12, weight: .semibold)
            .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modeList: some View {
        VStack(spacing: 12) {
            ForEach(availableModes, id: \.self) { mode in
                modeRow(mode)
            }
        }
    }

    private func modeRow(_ mode: PracticeMode) -> some View {
        Button(
            action: { selectedMode = mode },
            label: {
                HStack(spacing: 16) {
                    Text(mode.glyph)
                        .font(KakitoriTheme.japaneseDisplayFont(size: 44))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KakitoriTheme.paper.opacity(0.5))
                        )
                        .foregroundStyle(KakitoriTheme.ink)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.label)
                            .font(.body.bold())
                            .foregroundStyle(KakitoriTheme.ink)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    selectionRing(isSelected: selectedMode == mode)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
        )
        .accessibilityIdentifier(mode.accessibilityIdentifier)
    }

    private func selectionRing(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(KakitoriTheme.ink.opacity(0.2), lineWidth: 1)
                .frame(width: 24, height: 24)

            if isSelected {
                Circle()
                    .fill(KakitoriTheme.accent)
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 24, height: 24)
    }

    private var startButton: some View {
        Button(
            action: {
                guard let mode = selectedMode else { return }
                onStart(mode)
            },
            label: {
                Text("Start writing")
                    .kakitoriFont(size: 16, weight: .semibold)
                    .foregroundStyle(KakitoriTheme.paper)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(KakitoriTheme.accent)
            }
        )
        .accessibilityIdentifier("start-writing")
        .padding(16)
    }
}

#Preview {
    DeckSetupSheet(
        jpTitle: "ひらがな",
        enTitle: "Hiragana",
        dueCount: 10,
        availableModes: [.trace, .listen, .recall, .mixed],
        onStart: { _ in },
        onClose: {}
    )
}
