import SwiftUI

struct SettingsView: View {
    @AppStorage("newCardsPerDay") private var newCardsPerDay = 10
    @AppStorage("maxReviewsPerDay") private var maxReviewsPerDay = 100
    @AppStorage("audioAutoplay") private var audioAutoplay = true
    @AppStorage("showRomaji") private var showRomaji = true

    var body: some View {
        ZStack {
            KakitoriTheme.paper.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    HStack {
                        Text("New cards per day")
                        Spacer()
                        Stepper(
                            value: $newCardsPerDay,
                            in: 1 ... 50,
                            label: {
                                Text("\(newCardsPerDay)")
                            }
                        )
                        .accessibilityIdentifier("settings-new-per-day")
                    }

                    HStack {
                        Text("Max reviews per day")
                        Spacer()
                        Stepper(
                            value: $maxReviewsPerDay,
                            in: 10 ... 500,
                            label: {
                                Text("\(maxReviewsPerDay)")
                            }
                        )
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
