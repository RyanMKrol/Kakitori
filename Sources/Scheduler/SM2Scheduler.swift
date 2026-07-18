import Foundation

struct SM2Scheduler {
    let fuzzEnabled: Bool

    init(fuzzEnabled: Bool = true) {
        self.fuzzEnabled = fuzzEnabled
    }

    func apply(
        _ grade: Grade,
        to card: ScheduleSnapshot,
        now: Date,
        rng: inout some RandomNumberGenerator
    ) -> ScheduleSnapshot {
        switch card.state {
        case .new:
            applyLearning(grade, to: ScheduleSnapshot(
                state: .learning,
                stepIndex: 0,
                easeFactor: card.easeFactor,
                intervalDays: card.intervalDays,
                dueAt: card.dueAt,
                lapses: card.lapses
            ), now: now)
        case .learning:
            applyLearning(grade, to: card, now: now)
        case .relearning:
            applyRelearning(grade, to: card, now: now)
        case .review:
            applyReview(grade, to: card, now: now, rng: &rng)
        }
    }

    private func applyLearning(_ grade: Grade, to card: ScheduleSnapshot, now: Date) -> ScheduleSnapshot {
        let steps = SRSConstants.learningStepsSeconds
        let currentIndex = min(max(card.stepIndex, 0), steps.count - 1)

        switch grade {
        case .again:
            return ScheduleSnapshot(
                state: .learning,
                stepIndex: 0,
                easeFactor: card.easeFactor,
                intervalDays: card.intervalDays,
                dueAt: now.addingTimeInterval(steps[0]),
                lapses: card.lapses
            )
        case .hard:
            return ScheduleSnapshot(
                state: .learning,
                stepIndex: currentIndex,
                easeFactor: card.easeFactor,
                intervalDays: card.intervalDays,
                dueAt: now.addingTimeInterval(steps[currentIndex]),
                lapses: card.lapses
            )
        case .good:
            return applyLearningGood(currentIndex: currentIndex, steps: steps, to: card, now: now)
        case .easy:
            return graduate(
                card,
                intervalDays: SRSConstants.easyGraduatingIntervalDays,
                now: now
            )
        }
    }

    private func applyLearningGood(
        currentIndex: Int,
        steps: [TimeInterval],
        to card: ScheduleSnapshot,
        now: Date
    ) -> ScheduleSnapshot {
        if currentIndex == steps.count - 1 {
            return graduate(card, intervalDays: SRSConstants.graduatingIntervalDays, now: now)
        }
        let newIndex = currentIndex + 1
        return ScheduleSnapshot(
            state: .learning,
            stepIndex: newIndex,
            easeFactor: card.easeFactor,
            intervalDays: card.intervalDays,
            dueAt: now.addingTimeInterval(steps[newIndex]),
            lapses: card.lapses
        )
    }

    private func graduate(_ card: ScheduleSnapshot, intervalDays: Double, now: Date) -> ScheduleSnapshot {
        ScheduleSnapshot(
            state: .review,
            stepIndex: 0,
            easeFactor: card.easeFactor,
            intervalDays: intervalDays,
            dueAt: now.addingTimeInterval(intervalDays * SRSConstants.secondsPerDay),
            lapses: card.lapses
        )
    }

    private func applyRelearning(_ grade: Grade, to card: ScheduleSnapshot, now: Date) -> ScheduleSnapshot {
        switch grade {
        case .again, .hard:
            return ScheduleSnapshot(
                state: .relearning,
                stepIndex: 0,
                easeFactor: card.easeFactor,
                intervalDays: card.intervalDays,
                dueAt: now.addingTimeInterval(SRSConstants.relearningStepSeconds),
                lapses: card.lapses
            )
        case .good:
            return graduate(card, intervalDays: relapsedIntervalDays(for: card), now: now)
        case .easy:
            let intervalDays = max(SRSConstants.easyGraduatingIntervalDays, relapsedIntervalDays(for: card))
            return graduate(card, intervalDays: intervalDays, now: now)
        }
    }

    private func relapsedIntervalDays(for card: ScheduleSnapshot) -> Double {
        max(1, (card.intervalDays * SRSConstants.lapseIntervalMultiplier).rounded())
    }

    private func applyReview(
        _ grade: Grade,
        to card: ScheduleSnapshot,
        now: Date,
        rng: inout some RandomNumberGenerator
    ) -> ScheduleSnapshot {
        switch grade {
        case .again:
            let newEF = max(SRSConstants.minimumEase, card.easeFactor + SRSConstants.againEaseDelta)
            return ScheduleSnapshot(
                state: .relearning,
                stepIndex: 0,
                easeFactor: newEF,
                intervalDays: card.intervalDays,
                dueAt: now.addingTimeInterval(SRSConstants.relearningStepSeconds),
                lapses: card.lapses + 1
            )
        case .hard:
            return applyReviewHard(card, now: now, rng: &rng)
        case .good:
            return applyReviewGood(card, now: now, rng: &rng)
        case .easy:
            return applyReviewEasy(card, now: now, rng: &rng)
        }
    }

    private func applyReviewHard(
        _ card: ScheduleSnapshot,
        now: Date,
        rng: inout some RandomNumberGenerator
    ) -> ScheduleSnapshot {
        let newEF = max(SRSConstants.minimumEase, card.easeFactor + SRSConstants.hardEaseDelta)
        let newI = clampReviewInterval(card.intervalDays * SRSConstants.hardIntervalMultiplier)
        return ScheduleSnapshot(
            state: .review,
            stepIndex: 0,
            easeFactor: newEF,
            intervalDays: newI,
            dueAt: calculateDueAt(intervalDays: newI, now: now, rng: &rng),
            lapses: card.lapses
        )
    }

    private func applyReviewGood(
        _ card: ScheduleSnapshot,
        now: Date,
        rng: inout some RandomNumberGenerator
    ) -> ScheduleSnapshot {
        let newI = clampReviewInterval(card.intervalDays * card.easeFactor)
        return ScheduleSnapshot(
            state: .review,
            stepIndex: 0,
            easeFactor: card.easeFactor,
            intervalDays: newI,
            dueAt: calculateDueAt(intervalDays: newI, now: now, rng: &rng),
            lapses: card.lapses
        )
    }

    private func applyReviewEasy(
        _ card: ScheduleSnapshot,
        now: Date,
        rng: inout some RandomNumberGenerator
    ) -> ScheduleSnapshot {
        let newEF = card.easeFactor + SRSConstants.easyEaseDelta
        let newI = clampReviewInterval(card.intervalDays * newEF * SRSConstants.easyBonus)
        return ScheduleSnapshot(
            state: .review,
            stepIndex: 0,
            easeFactor: newEF,
            intervalDays: newI,
            dueAt: calculateDueAt(intervalDays: newI, now: now, rng: &rng),
            lapses: card.lapses
        )
    }

    private func clampReviewInterval(_ interval: Double) -> Double {
        min(SRSConstants.maximumIntervalDays, max(SRSConstants.minimumReviewIntervalDays, interval.rounded()))
    }

    private func calculateDueAt(
        intervalDays: Double,
        now: Date,
        rng: inout some RandomNumberGenerator
    ) -> Date {
        let fuzz = shouldApplyFuzz(to: intervalDays)
            ? Double.random(in: -SRSConstants.fuzzFraction ... SRSConstants.fuzzFraction, using: &rng)
            : 0
        let secondsOffset = intervalDays * SRSConstants.secondsPerDay * (1 + fuzz)
        return now.addingTimeInterval(secondsOffset)
    }

    private func shouldApplyFuzz(to intervalDays: Double) -> Bool {
        fuzzEnabled && intervalDays >= SRSConstants.fuzzMinimumIntervalDays
    }
}
