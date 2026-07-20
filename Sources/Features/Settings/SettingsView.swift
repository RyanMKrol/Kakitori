import Combine
import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage("newCardsPerDay") private var newCardsPerDay = 10
    @AppStorage("maxReviewsPerDay") private var maxReviewsPerDay = 100
    @AppStorage("audioAutoplay") private var audioAutoplay = true
    @AppStorage("showRomaji") private var showRomaji = true

    @Environment(\.modelContext) private var modelContext
    @Environment(DeckLoadModel.self) private var deckLoad

    @State private var newCardsText: String
    @State private var maxReviewsText: String
    @State private var showResetConfirm = false
    @FocusState private var focusedField: FocusedField?

    enum FocusedField {
        case newCards
        case maxReviews
    }

    init() {
        _newCardsText = State(initialValue: "")
        _maxReviewsText = State(initialValue: "")
    }

    var body: some View {
        ZStack {
            KakitoriTheme.paper.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    HStack {
                        Text("New cards per day")
                        Spacer()
                        TextField(
                            "\(newCardsPerDay)",
                            text: $newCardsText
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .kakitoriFont(size: 14)
                        .foregroundStyle(KakitoriTheme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(KakitoriTheme.inkFaint)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 60)
                        .onReceive(Just(newCardsPerDay)) { value in
                            if newCardsText.isEmpty {
                                newCardsText = "\(value)"
                            }
                        }
                        .focused($focusedField, equals: .newCards)
                        .onSubmit {
                            commitNewCardsValue()
                        }
                        .onChange(of: focusedField) {
                            if focusedField != .newCards, !newCardsText.isEmpty {
                                commitNewCardsValue()
                            }
                        }
                        .accessibilityIdentifier("settings-new-per-day")
                    }

                    HStack {
                        Text("Max reviews per day")
                        Spacer()
                        TextField(
                            "\(maxReviewsPerDay)",
                            text: $maxReviewsText
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .kakitoriFont(size: 14)
                        .foregroundStyle(KakitoriTheme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(KakitoriTheme.inkFaint)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 60)
                        .onReceive(Just(maxReviewsPerDay)) { value in
                            if maxReviewsText.isEmpty {
                                maxReviewsText = "\(value)"
                            }
                        }
                        .focused($focusedField, equals: .maxReviews)
                        .onSubmit {
                            commitMaxReviewsValue()
                        }
                        .onChange(of: focusedField) {
                            if focusedField != .maxReviews, !maxReviewsText.isEmpty {
                                commitMaxReviewsValue()
                            }
                        }
                        .accessibilityIdentifier("settings-max-reviews")
                    }

                    Toggle("Audio autoplay", isOn: $audioAutoplay)
                        .accessibilityIdentifier("settings-autoplay")

                    Toggle("Show romaji", isOn: $showRomaji)
                        .accessibilityIdentifier("settings-romaji")
                }
                .kakitoriFont(size: 16)
                .foregroundStyle(KakitoriTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(KakitoriTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: KakitoriTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: KakitoriTheme.radiusMedium)
                        .stroke(KakitoriTheme.boxLine, lineWidth: 1)
                )
                .padding()

                resetButton

                Spacer()
            }
        }
        .navigationTitle("Settings")
        .alert("Reset everything?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { performReset() }
        } message: {
            Text("Deletes all your progress and reloads the decks from scratch. Your settings are kept.")
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showResetConfirm = true
        } label: {
            Text("Reset all data")
                .kakitoriFont(size: 16, weight: .semibold)
                .foregroundStyle(KakitoriTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(KakitoriTheme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: KakitoriTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: KakitoriTheme.radiusMedium)
                        .stroke(KakitoriTheme.accent.opacity(0.3), lineWidth: 1)
                )
        }
        .accessibilityIdentifier("settings-reset")
        .padding(.horizontal)
    }

    private func performReset() {
        try? AppDataReset.resetAll(container: modelContext.container)
        Task { await deckLoad.retry(container: modelContext.container) }
    }

    private func commitNewCardsValue() {
        let min = 1
        let max = 50
        if let value = Int(newCardsText.trimmingCharacters(in: .whitespaces)), value >= min, value <= max {
            newCardsPerDay = value
        }
        newCardsText = "\(newCardsPerDay)"
    }

    private func commitMaxReviewsValue() {
        let min = 10
        let max = 500
        if let value = Int(maxReviewsText.trimmingCharacters(in: .whitespaces)), value >= min, value <= max {
            maxReviewsPerDay = value
        }
        maxReviewsText = "\(maxReviewsPerDay)"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(DeckLoadModel())
    .modelContainer(for: [Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self], inMemory: true)
}
