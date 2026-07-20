#if DEBUG
    @testable import Kakitori
    import SwiftData
    import SwiftUI
    import XCTest

    @MainActor final class CanvasPaneRenderTests: XCTestCase {
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

        func testCanvasPaneRendersGuideBoxesAndPills() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 18, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Hiragana Basics", sourceDeckName: "hiragana", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            makeReviewNote(target: "ありがとう", deck: deck, context: context)

            let viewModel = SessionViewModel(
                deck: deck,
                mode: .trace,
                modelContext: context,
                clock: clock,
                seed: 12345
            )

            let canvasPane = CanvasPaneView(viewModel: viewModel)
                .frame(width: 1194, height: 834)

            // `ImageRenderer` cannot flatten `WritingCanvas`'s `PKCanvasView` representable — it
            // substitutes an opaque "unsupported" glyph that would obscure the guide boxes. A
            // `UIHostingController` rendered via `drawHierarchy` composites it correctly (as proven by
            // `WritingCanvasPreviewSnapshotTests`), so this render check uses that path instead.
            let hostingController = UIHostingController(rootView: canvasPane)
            hostingController.view.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)

            let window = UIWindow(frame: hostingController.view.frame)
            window.rootViewController = hostingController
            window.isHidden = false
            hostingController.view.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))

            let imageRenderer = UIGraphicsImageRenderer(bounds: hostingController.view.bounds)
            let uiImage = imageRenderer.image { _ in
                hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
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

            let pngPath = screenshotsDir + "/T032-canvas.png"
            guard let pngData = uiImage.pngData() else {
                XCTFail("Failed to encode UIImage as PNG")
                return
            }

            try pngData.write(to: URL(fileURLWithPath: pngPath))
        }

        func testCanvasPaneCentersSingleCharacterBoxOnCompactWidth() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 18, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Kanji", sourceDeckName: "kanji", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            makeReviewNote(target: "火", deck: deck, context: context)

            let viewModel = SessionViewModel(
                deck: deck,
                mode: .trace,
                modelContext: context,
                clock: clock,
                seed: 12345
            )

            let canvasPane = CanvasPaneView(viewModel: viewModel)
                .environment(\.horizontalSizeClass, .compact)
                .frame(width: 390, height: 600)

            let hostingController = UIHostingController(rootView: canvasPane)
            hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)

            let window = UIWindow(frame: hostingController.view.frame)
            window.rootViewController = hostingController
            window.isHidden = false
            hostingController.view.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))

            let imageRenderer = UIGraphicsImageRenderer(bounds: hostingController.view.bounds)
            let uiImage = imageRenderer.image { _ in
                hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
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

            let pngPath = screenshotsDir + "/T074-canvas-compact-single-char.png"
            guard let pngData = uiImage.pngData() else {
                XCTFail("Failed to encode UIImage as PNG")
                return
            }

            try pngData.write(to: URL(fileURLWithPath: pngPath))
        }

        func testListenModeCanvasHidesGuideBoxes() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 18, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Hiragana Basics", sourceDeckName: "hiragana", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            makeReviewNote(target: "ありがとう", deck: deck, context: context)

            let viewModel = SessionViewModel(
                deck: deck,
                mode: .listen,
                modelContext: context,
                clock: clock,
                seed: 12345
            )

            let canvasPane = CanvasPaneView(viewModel: viewModel)
                .frame(width: 1194, height: 834)

            let hostingController = UIHostingController(rootView: canvasPane)
            hostingController.view.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)

            let window = UIWindow(frame: hostingController.view.frame)
            window.rootViewController = hostingController
            window.isHidden = false
            hostingController.view.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))

            let imageRenderer = UIGraphicsImageRenderer(bounds: hostingController.view.bounds)
            let uiImage = imageRenderer.image { _ in
                hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
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

            let pngPath = screenshotsDir + "/T042-canvas-listen.png"
            guard let pngData = uiImage.pngData() else {
                XCTFail("Failed to encode UIImage as PNG")
                return
            }

            try pngData.write(to: URL(fileURLWithPath: pngPath))
        }

        func testTranslateModeCanvasHidesGuideBoxes() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 18, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Kanji", sourceDeckName: "kanji", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            let note = Note(target: "火", english: "fire", script: .kanji)
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

            let viewModel = SessionViewModel(
                deck: deck,
                mode: .translate,
                modelContext: context,
                clock: clock,
                seed: 12345
            )

            let canvasPane = CanvasPaneView(viewModel: viewModel)
                .frame(width: 1194, height: 834)

            try renderCanvasPaneAndSave(canvasPane, filename: "T043-canvas-translate.png")
        }

        func testRecallModeCanvasHidesGuideBoxes() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 18, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            let deck = Deck(name: "Kanji", sourceDeckName: "kanji", importedAt: fixedTime)
            let section = Section(name: "Section 1", orderIndex: 0)
            deck.sections = [section]
            context.insert(deck)
            context.insert(section)

            let note = Note(target: "火", pronunciation: "ひ", english: "fire", script: .kanji)
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

            let viewModel = SessionViewModel(
                deck: deck,
                mode: .recall,
                modelContext: context,
                clock: clock,
                seed: 12345
            )

            let canvasPane = CanvasPaneView(viewModel: viewModel)
                .frame(width: 1194, height: 834)

            try renderCanvasPaneAndSave(canvasPane, filename: "T044-canvas-recall.png")
        }

        private func renderCanvasPaneAndSave(_ view: some View, filename: String) throws {
            let hostingController = UIHostingController(rootView: view)
            hostingController.view.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)

            let window = UIWindow(frame: hostingController.view.frame)
            window.rootViewController = hostingController
            window.isHidden = false
            hostingController.view.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))

            let imageRenderer = UIGraphicsImageRenderer(bounds: hostingController.view.bounds)
            let uiImage = imageRenderer.image { _ in
                hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
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
