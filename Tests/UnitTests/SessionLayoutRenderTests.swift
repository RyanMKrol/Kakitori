#if DEBUG
    @testable import Kakitori
    import SwiftData
    import SwiftUI
    import XCTest

    /// Renders the session screen at the iPad's two orientations, in both the prompt and the
    /// revealed phase, to `screenshots/` for visual inspection. The session layout is a single
    /// vertical stack whose prompt band is sized from the available height, so landscape (short and
    /// wide) and portrait (tall) exercise genuinely different arrangements of the same views.
    @MainActor final class SessionLayoutRenderTests: XCTestCase {
        private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

        private func makeViewModel(
            mode: PracticeMode,
            target: String = "ザ",
            reading: String = "za"
        ) throws -> SessionViewModel {
            let container = try ModelContainer(
                for: Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = ModelContext(container)

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tokyo
            let fixedTime = calendar.date(from: DateComponents(
                year: 2026, month: 7, day: 25, hour: 12, minute: 0
            ))!
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Katakana", sourceDeckName: "katakana", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            let note = Note(
                target: target,
                pronunciation: reading,
                english: reading,
                script: .katakana,
                units: [target]
            )
            note.audioFilename = "\(reading).mp3"
            let schedule = CardSchedule(
                state: .review,
                stepIndex: 0,
                easeFactor: 2.5,
                intervalDays: 10,
                dueAt: Date.distantPast,
                lapses: 0
            )
            note.schedule = schedule
            deck.sections[0].notes.append(note)
            context.insert(note)
            context.insert(schedule)

            return SessionViewModel(
                deck: deck, mode: mode, modelContext: context, clock: clock, seed: 12345
            )
        }

        private func render(_ viewModel: SessionViewModel, size: CGSize, named filename: String) throws {
            let view = SessionView(viewModel: viewModel, onClose: {})
                .frame(width: size.width, height: size.height)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2

            let image = try XCTUnwrap(renderer.uiImage, "SessionView should render")
            let data = try XCTUnwrap(image.pngData())

            let repoRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let directory = repoRoot.appendingPathComponent("screenshots")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(filename))
        }

        func testLandscapePromptAndAnswer() throws {
            let landscape = CGSize(width: 1180, height: 820)

            let prompt = try makeViewModel(mode: .listen)
            try render(prompt, size: landscape, named: "layout-landscape-prompt.png")

            let revealed = try makeViewModel(mode: .listen)
            revealed.showAnswer()
            try render(revealed, size: landscape, named: "layout-landscape-answer.png")
        }

        /// き is the character that shows the app is drawing handwritten forms: written by hand its
        /// bottom curve is a separate stroke with a visible gap, and every system face joins it on.
        /// Rendered through the real answer view — if the bundled face ever stops loading, the gap
        /// closes here and it's obvious in the screenshot.
        func testAnswerRendersKiWithItsGap() throws {
            let revealed = try makeViewModel(mode: .trace, target: "き", reading: "ki")
            revealed.showAnswer()
            try render(revealed, size: CGSize(width: 820, height: 1180), named: "fonts-ki-answer.png")
        }

        // No trace-guide render here: the guide is drawn behind the PencilKit canvas, and
        // ImageRenderer replaces any UIViewRepresentable with a placeholder that covers it. The
        // guide has to be checked on a running simulator.

        func testPortraitPromptAndAnswer() throws {
            let portrait = CGSize(width: 820, height: 1180)

            let prompt = try makeViewModel(mode: .trace)
            try render(prompt, size: portrait, named: "layout-portrait-prompt.png")

            let revealed = try makeViewModel(mode: .trace)
            revealed.showAnswer()
            try render(revealed, size: portrait, named: "layout-portrait-answer.png")
        }
    }
#endif
