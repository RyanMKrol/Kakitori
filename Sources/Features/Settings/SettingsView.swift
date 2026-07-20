import Combine
import SwiftUI

struct SettingsView: View {
    @AppStorage("newCardsPerDay") private var newCardsPerDay = 10
    @AppStorage("maxReviewsPerDay") private var maxReviewsPerDay = 100
    @AppStorage("audioAutoplay") private var audioAutoplay = true
    @AppStorage("showRomaji") private var showRomaji = true

    @State private var newCardsText: String
    @State private var maxReviewsText: String
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
                        .multilineTextAlignment(.trailing)
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
                        .multilineTextAlignment(.trailing)
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
                .padding(20)
                .background(KakitoriTheme.paper)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Settings")
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
}
