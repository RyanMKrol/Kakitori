@testable import Kakitori
import SwiftData
import XCTest

final class DailyStatsTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )
        return calendar.date(from: components)!
    }

    private var fixedClock: AppClock {
        AppClock.fixed(makeDate(year: 2026, month: 7, day: 17, hour: 12, minute: 0), timeZone: tokyo)
    }

    func testModelRoundTrip() throws {
        let container = try ModelContainer(
            for: DailyStats.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let stats = DailyStats(
            day: "2026-07-17", cardsWritten: 12, newIntroduced: 3, reviewsDone: 9, secondsStudied: 360
        )
        context.insert(stats)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DailyStats>())
        let refetched = try XCTUnwrap(fetched.first)
        XCTAssertEqual(refetched.day, "2026-07-17")
        XCTAssertEqual(refetched.cardsWritten, 12)
        XCTAssertEqual(refetched.newIntroduced, 3)
        XCTAssertEqual(refetched.reviewsDone, 9)
        XCTAssertEqual(refetched.secondsStudied, 360)
    }

    func testStreakTodayActiveCountsAllConsecutiveDays() {
        let clock = fixedClock
        let activeDays: Set = ["2026-07-17", "2026-07-16", "2026-07-15"]
        XCTAssertEqual(DailyStats.currentStreak(activeDays: activeDays, now: clock.now(), clock: clock), 3)
    }

    func testStreakTodayInactiveYesterdayActiveStillShown() {
        let clock = fixedClock
        let activeDays: Set = ["2026-07-16", "2026-07-15"]
        XCTAssertEqual(DailyStats.currentStreak(activeDays: activeDays, now: clock.now(), clock: clock), 2)
    }

    func testStreakGapBreaksTheRun() {
        let clock = fixedClock
        let activeDays: Set = ["2026-07-17", "2026-07-15"]
        XCTAssertEqual(DailyStats.currentStreak(activeDays: activeDays, now: clock.now(), clock: clock), 1)
    }

    func testStreakNeitherTodayNorYesterdayActiveIsZero() {
        let clock = fixedClock
        let activeDays: Set = ["2026-07-15"]
        XCTAssertEqual(DailyStats.currentStreak(activeDays: activeDays, now: clock.now(), clock: clock), 0)
    }

    func testStreakEmptyActiveDaysIsZero() {
        let clock = fixedClock
        XCTAssertEqual(DailyStats.currentStreak(activeDays: [], now: clock.now(), clock: clock), 0)
    }

    func testStreakFlowsThroughFourAMRollover() {
        let now = makeDate(year: 2026, month: 7, day: 18, hour: 3, minute: 0)
        let clock = AppClock.fixed(now, timeZone: tokyo)
        XCTAssertEqual(DailyStats.currentStreak(activeDays: ["2026-07-17"], now: now, clock: clock), 1)
    }

    // MARK: - deckKey additive migration

    /// Reopening a store written before `deckKey` existed (via `KakitoriSchemaV1`) must not
    /// crash, and the pre-existing row must survive — as the legacy/global sentinel
    /// (`deckKey == nil`) — once migrated to `KakitoriSchemaV2` via `KakitoriMigrationPlan`.
    func testPreDeckKeyRowSurvivesAdditiveSchemaChange() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyStatsMigrationTest-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
        }

        do {
            let v1Schema = Schema(versionedSchema: KakitoriSchemaV1.self)
            let legacyConfiguration = ModelConfiguration(schema: v1Schema, url: storeURL)
            let legacyContainer = try ModelContainer(for: v1Schema, configurations: legacyConfiguration)
            let legacyContext = ModelContext(legacyContainer)
            legacyContext.insert(KakitoriSchemaV1.DailyStats(
                day: "2026-07-17", cardsWritten: 5, newIntroduced: 2, reviewsDone: 3, secondsStudied: 120
            ))
            try legacyContext.save()
        }

        let v2Schema = Schema(versionedSchema: KakitoriSchemaV2.self)
        let currentConfiguration = ModelConfiguration(schema: v2Schema, url: storeURL)
        let migratedContainer = try ModelContainer(
            for: v2Schema,
            migrationPlan: KakitoriMigrationPlan.self,
            configurations: currentConfiguration
        )
        let migratedContext = ModelContext(migratedContainer)

        let rows = try migratedContext.fetch(FetchDescriptor<DailyStats>())
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.day, "2026-07-17")
        XCTAssertEqual(row.cardsWritten, 5)
        XCTAssertEqual(row.newIntroduced, 2)
        XCTAssertEqual(row.reviewsDone, 3)
        XCTAssertEqual(row.secondsStudied, 120)
        XCTAssertNil(row.deckKey, "a pre-migration row has no deck association — it's the legacy global sentinel")
    }
}
