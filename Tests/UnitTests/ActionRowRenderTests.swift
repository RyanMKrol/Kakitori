#if DEBUG
    @testable import Kakitori
    import SwiftData
    import SwiftUI
    import XCTest

    @MainActor final class ActionRowRenderTests: XCTestCase {
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

        private func makeReviewNote(target: String, deck: Deck, context: ModelContext) {
            let note = Note(target: target, script: .hiragana)
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
        }

        func testActionRowShowAnswerButton() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Hiragana Basics", sourceDeckName: "hiragana", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            makeReviewNote(target: "あ", deck: deck, context: context)

            let viewModel = SessionViewModel(
                deck: deck,
                mode: .trace,
                modelContext: context,
                clock: clock,
                seed: 12345
            )

            let actionRow = ActionRowView(viewModel: viewModel)
                .frame(width: 1194, height: 834)

            let renderer = ImageRenderer(content: actionRow)
            renderer.scale = 2

            guard let uiImage = renderer.uiImage else {
                XCTFail("Failed to render ActionRowView to UIImage")
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

            let pngPath = screenshotsDir + "/T033-show-answer.png"
            guard let pngData = uiImage.pngData() else {
                XCTFail("Failed to encode UIImage as PNG")
                return
            }

            try pngData.write(to: URL(fileURLWithPath: pngPath))

            XCTAssertNotNil(uiImage, "Rendered image should not be nil")
        }

        func testActionRowGradeButtons() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Hiragana Basics", sourceDeckName: "hiragana", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            makeReviewNote(target: "あ", deck: deck, context: context)

            let viewModel = SessionViewModel(
                deck: deck,
                mode: .trace,
                modelContext: context,
                clock: clock,
                seed: 12345
            )

            viewModel.showAnswer()

            let actionRow = ActionRowView(viewModel: viewModel)
                .frame(width: 1194, height: 834)

            let renderer = ImageRenderer(content: actionRow)
            renderer.scale = 2

            guard let uiImage = renderer.uiImage else {
                XCTFail("Failed to render ActionRowView to UIImage")
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

            let pngPath = screenshotsDir + "/T033-grades.png"
            guard let pngData = uiImage.pngData() else {
                XCTFail("Failed to encode UIImage as PNG")
                return
            }

            try pngData.write(to: URL(fileURLWithPath: pngPath))

            XCTAssertNotNil(uiImage, "Rendered image should not be nil")
        }
    }
#endif
