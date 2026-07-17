@testable import Kakitori
import SwiftData
import XCTest

final class CardScheduleModelTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Deck.self, Section.self, Note.self, CardSchedule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testDefaultInitialValues() {
        let schedule = CardSchedule()
        XCTAssertEqual(schedule.state, .new)
        XCTAssertEqual(schedule.stepIndex, 0)
        XCTAssertEqual(schedule.easeFactor, 2.5)
        XCTAssertEqual(schedule.intervalDays, 0)
        XCTAssertNil(schedule.dueAt)
        XCTAssertEqual(schedule.lapses, 0)
    }

    func testNoteScheduleLinkRoundTripsBothDirections() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let note = Note(target: "あ", script: .hiragana, units: ["あ"])
        let schedule = CardSchedule()
        context.insert(note)
        context.insert(schedule)
        note.schedule = schedule
        try context.save()

        let fetchedNotes = try context.fetch(FetchDescriptor<Note>())
        let refetchedNote = try XCTUnwrap(fetchedNotes.first)
        let refetchedSchedule = try XCTUnwrap(refetchedNote.schedule)
        XCTAssertTrue(refetchedSchedule.note === refetchedNote)
    }

    func testNonDefaultValuesRoundTrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let schedule = CardSchedule(
            state: .review,
            intervalDays: 12.0,
            dueAt: fixedDate,
            lapses: 2
        )
        context.insert(schedule)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CardSchedule>())
        let refetched = try XCTUnwrap(fetched.first)
        XCTAssertEqual(refetched.state, .review)
        XCTAssertEqual(refetched.intervalDays, 12.0)
        XCTAssertEqual(refetched.dueAt, fixedDate)
        XCTAssertEqual(refetched.lapses, 2)
    }
}
