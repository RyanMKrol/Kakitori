import Foundation

enum Grade: String, CaseIterable, Hashable {
    case again
    case hard
    case good
    case easy
}

struct ScheduleSnapshot: Equatable {
    let state: CardState
    let stepIndex: Int
    let easeFactor: Double
    let intervalDays: Double
    let dueAt: Date?
    let lapses: Int
}

struct SchedulePreview: Equatable {
    let dueAt: Date
    let intervalDays: Double
    let label: String
}

protocol Scheduler {
    func preview(for card: ScheduleSnapshot, now: Date) -> [Grade: SchedulePreview]
    func apply(
        _ grade: Grade,
        to card: ScheduleSnapshot,
        now: Date,
        rng: inout some RandomNumberGenerator
    ) -> ScheduleSnapshot
}

enum SRSConstants {
    static let learningStepsSeconds: [TimeInterval] = [60, 600]
    static let graduatingIntervalDays: Double = 1
    static let easyGraduatingIntervalDays: Double = 4
    static let relearningStepSeconds: TimeInterval = 600
    static let initialEase: Double = 2.5
    static let minimumEase: Double = 1.3
    static let againEaseDelta: Double = -0.20
    static let hardEaseDelta: Double = -0.15
    static let easyEaseDelta: Double = 0.15
    static let hardIntervalMultiplier: Double = 1.2
    static let easyBonus: Double = 1.3
    static let maximumIntervalDays: Double = 365
    static let minimumReviewIntervalDays: Double = 1
    static let lapseIntervalMultiplier: Double = 0.5
    static let fuzzFraction: Double = 0.05
    static let fuzzMinimumIntervalDays: Double = 3
    static let defaultNewPerDay: Int = 10
    static let defaultMaxReviewsPerDay: Int = 100
    static let dayRolloverHour: Int = 4
    static let secondsPerDay: TimeInterval = 86400
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
