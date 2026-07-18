#if DEBUG
    @testable import Kakitori
    import SwiftData
    import SwiftUI
    import XCTest

    @MainActor final class PromptPaneRenderTests: XCTestCase {
        private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

        private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tokyo
            let components = DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute
            )
            return calendar.date(from: components)!
        }

        private func makeContainer() throws -> ModelContainer {
            let schema = Schema([
                Deck.self,
                Section.self,
                Note.self,
                CardSchedule.self,
                DailyStats.self,
            ])
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        private func setupViewModelWithNote(
            pronunciation: String,
            english: String?,
            hint: String?
        ) throws -> SessionViewModel {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Hiragana Basics", sourceDeckName: "hiragana", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            let note = Note(
                target: "あ",
                pronunciation: pronunciation,
                english: english,
                hint: hint,
                script: .hiragana,
                units: ["あ"]
            )
            let schedule = CardSchedule(
                state: .new,
                stepIndex: 0,
                easeFactor: 2.5,
                intervalDays: 0,
                dueAt: Date.distantPast,
                lapses: 0
            )
            note.schedule = schedule
            deck.sections[0].notes.append(note)
            context.insert(note)
            context.insert(schedule)

            return SessionViewModel(
                deck: deck,
                mode: .trace,
                modelContext: context,
                clock: clock,
                seed: 12345
            )
        }

        func testPromptPaneRendersBeforeReveal() throws {
            let viewModel = try setupViewModelWithNote(
                pronunciation: "あ",
                english: nil,
                hint: nil
            )

            let promptPane = PromptPaneView(viewModel: viewModel)
                .frame(width: 476, height: 834)
                .background(KakitoriTheme.paper)

            try renderAndSaveScreenshot(promptPane, filename: "T031-prompt.png")
        }

        func testPromptPaneRendersAfterReveal() throws {
            let viewModel = try setupViewModelWithNote(
                pronunciation: "あ",
                english: "hiragana 'a'",
                hint: "the first character"
            )

            viewModel.showAnswer()

            let promptPane = PromptPaneView(viewModel: viewModel)
                .frame(width: 476, height: 834)
                .background(KakitoriTheme.paper)

            try renderAndSaveScreenshot(promptPane, filename: "T031-answer.png")
        }

        private func renderAndSaveScreenshot(_ view: some View, filename: String) throws {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2

            guard let uiImage = renderer.uiImage else {
                XCTFail("Failed to render view to UIImage")
                return
            }

            let repoRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path

            let screenshotsDir = repoRoot + "/screenshots"
            try FileManager.default.createDirectory(
                atPath: screenshotsDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let pngPath = screenshotsDir + "/" + filename
            guard let pngData = uiImage.pngData() else {
                XCTFail("Failed to encode UIImage as PNG")
                return
            }

            try pngData.write(to: URL(fileURLWithPath: pngPath))
        }
    }
#endif
