import Foundation
@testable import Kakitori
import SwiftData
import XCTest

@MainActor
final class StatsRecorderTests: XCTestCase {
    private var modelContext: ModelContext!

    override func setUp() {
        super.setUp()

        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: DailyStats.self, configurations: config)
            modelContext = ModelContext(container)
        } catch {
            XCTFail("Failed to set up ModelContext: \(error)")
        }
    }

    override func tearDown() {
        modelContext = nil
        super.tearDown()
    }

    func testRecordGradeWithNewStateAtNormalTime() throws {
        let components = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordGrade(previousState: .new, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.cardsWritten, 1)
        XCTAssertEqual(stats?.newIntroduced, 1)
        XCTAssertEqual(stats?.reviewsDone, 0)
    }

    func testRecordGradeWith359AmLandsOnPreviousDay() throws {
        let components = DateComponents(year: 2026, month: 7, day: 18, hour: 3, minute: 59)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordGrade(previousState: .learning, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.cardsWritten, 1)
        XCTAssertEqual(stats?.newIntroduced, 0)
        XCTAssertEqual(stats?.reviewsDone, 0)

        let futureStats = try fetchDailyStats(for: "2026-07-18")
        XCTAssertNil(futureStats)
    }

    func testRecordGradeAt400AmLandsOnNewDay() throws {
        let components = DateComponents(year: 2026, month: 7, day: 18, hour: 4, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordGrade(previousState: .learning, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-18")
        XCTAssertEqual(stats?.cardsWritten, 1)
        XCTAssertEqual(stats?.newIntroduced, 0)
        XCTAssertEqual(stats?.reviewsDone, 0)

        let previousStats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertNil(previousStats)
    }

    func testRecordGradeWithReviewState() throws {
        let components = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordGrade(previousState: .review, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.cardsWritten, 1)
        XCTAssertEqual(stats?.newIntroduced, 0)
        XCTAssertEqual(stats?.reviewsDone, 1)
    }

    func testRecordGradeWithLearningState() throws {
        let components = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordGrade(previousState: .learning, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.cardsWritten, 1)
        XCTAssertEqual(stats?.newIntroduced, 0)
        XCTAssertEqual(stats?.reviewsDone, 0)
    }

    func testRecordGradeWithRelearnState() throws {
        let components = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordGrade(previousState: .relearning, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.cardsWritten, 1)
        XCTAssertEqual(stats?.newIntroduced, 0)
        XCTAssertEqual(stats?.reviewsDone, 0)
    }

    func testRecordStudySeconds() throws {
        let components = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordStudySeconds(30, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.secondsStudied, 30)
    }

    func testRecordStudySecondsAccumulates() throws {
        let components = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordStudySeconds(30, now: date, in: modelContext)
        try StatsRecorder.recordStudySeconds(45, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.secondsStudied, 75)
    }

    func testMultipleGradesAndSecondsOnSameDay() throws {
        let components = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordGrade(previousState: .new, now: date, in: modelContext)
        try StatsRecorder.recordStudySeconds(30, now: date, in: modelContext)
        try StatsRecorder.recordGrade(previousState: .review, now: date, in: modelContext)
        try StatsRecorder.recordStudySeconds(45, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.cardsWritten, 2)
        XCTAssertEqual(stats?.newIntroduced, 1)
        XCTAssertEqual(stats?.reviewsDone, 1)
        XCTAssertEqual(stats?.secondsStudied, 75)
    }

    func testNoDuplicateRowsAcrossDifferentDays() throws {
        let components1 = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date1 = Calendar.current.date(from: components1) else {
            XCTFail("Failed to create date1")
            return
        }

        let components2 = DateComponents(year: 2026, month: 7, day: 18, hour: 15, minute: 0)
        guard let date2 = Calendar.current.date(from: components2) else {
            XCTFail("Failed to create date2")
            return
        }

        try StatsRecorder.recordGrade(previousState: .new, now: date1, in: modelContext)
        try StatsRecorder.recordGrade(previousState: .new, now: date2, in: modelContext)

        let allStats = try fetchAllDailyStats()
        XCTAssertEqual(allStats.count, 2)

        let stats1 = allStats.first { $0.day == "2026-07-17" }
        XCTAssertNotNil(stats1)
        XCTAssertEqual(stats1?.cardsWritten, 1)

        let stats2 = allStats.first { $0.day == "2026-07-18" }
        XCTAssertNotNil(stats2)
        XCTAssertEqual(stats2?.cardsWritten, 1)
    }

    func testNoNegativeSeconds() throws {
        let components = DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 0)
        guard let date = Calendar.current.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        try StatsRecorder.recordStudySeconds(0, now: date, in: modelContext)

        let stats = try fetchDailyStats(for: "2026-07-17")
        XCTAssertEqual(stats?.secondsStudied, 0)
    }

    private func fetchDailyStats(for dayKey: String) throws -> DailyStats? {
        var descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.day == dayKey }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchAllDailyStats() throws -> [DailyStats] {
        let descriptor = FetchDescriptor<DailyStats>()
        return try modelContext.fetch(descriptor)
    }
}
