import Foundation
import SwiftData

@MainActor
enum StatsRecorder {
    /// Records a grade, updating the daily stats for the adjusted day.
    /// - Parameters:
    ///   - previousState: The card's CardState BEFORE the grade was applied.
    ///   - now: The current time.
    ///   - context: The SwiftData ModelContext to use for fetching/inserting the DailyStats.
    static func recordGrade(previousState: CardState, now: Date, in context: ModelContext) throws {
        let clock = AppClock.system
        let dayKey = clock.adjustedDay(for: now)
        let dailyStats = try fetchOrCreateDailyStats(for: dayKey, in: context)

        dailyStats.cardsWritten += 1

        if previousState == .new {
            dailyStats.newIntroduced += 1
        } else if previousState == .review {
            dailyStats.reviewsDone += 1
        }
    }

    /// Records study time, updating the daily stats for the adjusted day.
    /// - Parameters:
    ///   - seconds: The number of seconds studied.
    ///   - now: The current time.
    ///   - context: The SwiftData ModelContext to use for fetching/inserting the DailyStats.
    static func recordStudySeconds(_ seconds: Int, now: Date, in context: ModelContext) throws {
        let clock = AppClock.system
        let dayKey = clock.adjustedDay(for: now)
        let dailyStats = try fetchOrCreateDailyStats(for: dayKey, in: context)

        dailyStats.secondsStudied += seconds
    }

    private static func fetchOrCreateDailyStats(
        for dayKey: String,
        in context: ModelContext
    ) throws -> DailyStats {
        var fetchDescriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.day == dayKey }
        )
        fetchDescriptor.fetchLimit = 1

        if let existing = try context.fetch(fetchDescriptor).first {
            return existing
        }

        let newStats = DailyStats(day: dayKey)
        context.insert(newStats)
        return newStats
    }
}
