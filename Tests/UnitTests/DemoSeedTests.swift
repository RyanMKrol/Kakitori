#if DEBUG
    @testable import Kakitori
    import SwiftData
    import XCTest

    @MainActor final class DemoSeedTests: XCTestCase {
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

        func testSeedCreates3DecksAnd10NotesAnd3Stats() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            DemoSeed.seed(context: context, clock: clock)

            let decks = try context.fetch(FetchDescriptor<Deck>())
            XCTAssertEqual(decks.count, 3)

            let notes = try context.fetch(FetchDescriptor<Note>())
            XCTAssertEqual(notes.count, 10)

            for note in notes {
                XCTAssertNotNil(note.schedule, "Every note should have a schedule")
            }

            let stats = try context.fetch(FetchDescriptor<DailyStats>())
            XCTAssertEqual(stats.count, 3)
        }

        func testSeedCreatesDecksWithCorrectTitles() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            DemoSeed.seed(context: context, clock: clock)

            let decks = try context.fetch(FetchDescriptor<Deck>())
            let decksByName = Dictionary(uniqueKeysWithValues: decks.map { ($0.name, $0) })

            XCTAssertNotNil(decksByName["Hiragana"])
            XCTAssertEqual(decksByName["Hiragana"]?.jpTitle, "ひらがな")
            XCTAssertEqual(decksByName["Hiragana"]?.sourceDeckName, "Demo::Hiragana")

            XCTAssertNotNil(decksByName["Katakana"])
            XCTAssertEqual(decksByName["Katakana"]?.jpTitle, "カタカナ")
            XCTAssertEqual(decksByName["Katakana"]?.sourceDeckName, "Demo::Katakana")

            XCTAssertNotNil(decksByName["Kanji"])
            XCTAssertEqual(decksByName["Kanji"]?.jpTitle, "漢字")
            XCTAssertEqual(decksByName["Kanji"]?.sourceDeckName, "Demo::Kanji")
        }

        func testSeedContainsMixedScheduleStates() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            DemoSeed.seed(context: context, clock: clock)

            let notes = try context.fetch(FetchDescriptor<Note>())
            let schedules = notes.compactMap(\.schedule)

            let hasNew = schedules.contains { $0.state == .new }
            let hasLearning = schedules.contains { $0.state == .learning }
            let hasReview = schedules.contains { $0.state == .review }

            XCTAssertTrue(hasNew, "Should have at least one .new schedule")
            XCTAssertTrue(hasLearning, "Should have at least one .learning schedule")
            XCTAssertTrue(hasReview, "Should have at least one .review schedule")
        }

        func testSeedIsIdempotent() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            DemoSeed.seed(context: context, clock: clock)

            let firstDecks = try context.fetch(FetchDescriptor<Deck>())
            let firstNotes = try context.fetch(FetchDescriptor<Note>())
            let firstStats = try context.fetch(FetchDescriptor<DailyStats>())

            let firstDeckCount = firstDecks.count
            let firstNoteCount = firstNotes.count
            let firstStatsCount = firstStats.count

            DemoSeed.seed(context: context, clock: clock)

            let secondDecks = try context.fetch(FetchDescriptor<Deck>())
            let secondNotes = try context.fetch(FetchDescriptor<Note>())
            let secondStats = try context.fetch(FetchDescriptor<DailyStats>())

            XCTAssertEqual(secondDecks.count, firstDeckCount, "Deck count should not change after second seed")
            XCTAssertEqual(secondNotes.count, firstNoteCount, "Note count should not change after second seed")
            XCTAssertEqual(secondStats.count, firstStatsCount, "Stats count should not change after second seed")
        }

        func testDailyStatsUseCorrectDays() throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let fixedTime = makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0)
            let clock = AppClock.fixed(fixedTime, timeZone: tokyo)

            DemoSeed.seed(context: context, clock: clock)

            let stats = try context.fetch(FetchDescriptor<DailyStats>())
            let statsByDay = Dictionary(uniqueKeysWithValues: stats.map { ($0.day, $0) })

            let today = clock.adjustedDay(for: fixedTime)
            let yesterday = clock.adjustedDay(for: fixedTime.addingTimeInterval(-86400))
            let twoDaysAgo = clock.adjustedDay(for: fixedTime.addingTimeInterval(-172_800))

            XCTAssertNotNil(statsByDay[today], "Should have stats for today")
            XCTAssertNotNil(statsByDay[yesterday], "Should have stats for yesterday")
            XCTAssertNotNil(statsByDay[twoDaysAgo], "Should have stats for two days ago")

            XCTAssertEqual(statsByDay[today]?.cardsWritten, 12)
            XCTAssertEqual(statsByDay[yesterday]?.cardsWritten, 8)
            XCTAssertEqual(statsByDay[twoDaysAgo]?.cardsWritten, 15)
        }
    }
#endif
