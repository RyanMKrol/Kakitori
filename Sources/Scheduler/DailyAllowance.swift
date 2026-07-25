import Foundation

/// Pure, Foundation-only computation of "today's remaining allotment" (docs/03-srs-algorithm.md
/// §5) — the same caps `SessionQueue.build` applies — so every Home surface (the banner, deck
/// chips, `isAllCaughtUp`) reports what a session would actually serve, not the raw uncapped
/// backlog.
struct DailyAllowance: Equatable {
    let newCount: Int
    let learnCount: Int
    let dueCount: Int
    let scripts: Set<Script>

    var total: Int {
        newCount + learnCount + dueCount
    }

    var scriptCount: Int {
        scripts.count
    }

    var isAllCaughtUp: Bool {
        total == 0
    }

    /// Completed-today progress: X of X/Y, clamped to 0..Y.
    /// Y = newCount + learnCount + dueCount (today's full allotment).
    /// X = newIntroducedToday + reviewsDoneToday (clamped to 0..Y).
    static func completedToday(
        allotment: DailyAllowance,
        newIntroducedToday: Int,
        reviewsDoneToday: Int
    ) -> Int {
        let completed = newIntroducedToday + reviewsDoneToday
        return min(completed, allotment.total)
    }

    static func remainingAllowance(cap: Int, doneToday: Int) -> Int {
        max(0, cap - doneToday)
    }

    /// Has this deck finished its fixed daily target? This is the SINGLE definition of
    /// "done for today" — the Home deck card's "All caught up" line and the deck setup sheet's
    /// Free Study variant both go through it, so the two can never disagree about the same deck.
    /// (They used to: the card compared progress against the day's snapshotted target while the
    /// sheet asked whether the live allowance was empty, so a deck could read "All caught up" on
    /// Home and still offer "Start writing · 4 cards to study" on the sheet.)
    ///
    /// `dailyTarget` is the DailyStats snapshot for today; it is 0 before any study happens, in
    /// which case the live allowance total stands in as the denominator.
    static func isDayComplete(dailyTarget: Int, completedToday: Int, liveAllowanceTotal: Int) -> Bool {
        let allotment = dailyTarget > 0 ? dailyTarget : liveAllowanceTotal
        return allotment == 0 || min(completedToday, allotment) >= allotment
    }

    /// Today's allotment for a single pool of notes, mirroring `SessionQueue.build`'s cap logic:
    /// due learning/relearning is uncapped; new cards and due reviews are capped by the
    /// remaining daily allowance.
    static func forNotes(
        _ notes: [Note],
        now: Date,
        endOfToday: Date,
        newPerDay: Int = SRSConstants.defaultNewPerDay,
        maxReviewsPerDay: Int = SRSConstants.defaultMaxReviewsPerDay,
        newIntroducedToday: Int,
        reviewsDoneToday: Int
    ) -> DailyAllowance {
        let newNotes = notes.filter { $0.schedule?.state == .new }

        let learnNotes = notes.filter { note in
            guard let schedule = note.schedule,
                  schedule.state == .learning || schedule.state == .relearning,
                  let dueAt = schedule.dueAt else { return false }
            return dueAt <= now
        }

        let dueReviewNotes = notes
            .filter { note in
                guard let schedule = note.schedule, schedule.state == .review, let dueAt = schedule.dueAt else {
                    return false
                }
                return dueAt <= endOfToday
            }
            .sorted { ($0.schedule?.dueAt ?? endOfToday) < ($1.schedule?.dueAt ?? endOfToday) }

        let newAllowance = remainingAllowance(cap: newPerDay, doneToday: newIntroducedToday)
        let reviewAllowance = remainingAllowance(cap: maxReviewsPerDay, doneToday: reviewsDoneToday)

        let countedNew = Array(newNotes.prefix(newAllowance))
        let countedReviews = Array(dueReviewNotes.prefix(reviewAllowance))

        return DailyAllowance(
            newCount: countedNew.count,
            learnCount: learnNotes.count,
            dueCount: countedReviews.count,
            scripts: Set((countedNew + learnNotes + countedReviews).map(\.script))
        )
    }

    /// Today's allotment for a single deck.
    static func forDeck(
        _ deck: Deck,
        now: Date,
        endOfToday: Date,
        newPerDay: Int = SRSConstants.defaultNewPerDay,
        maxReviewsPerDay: Int = SRSConstants.defaultMaxReviewsPerDay,
        newIntroducedToday: Int,
        reviewsDoneToday: Int
    ) -> DailyAllowance {
        forNotes(
            deck.sections.flatMap(\.notes).filter { !$0.isDeleted },
            now: now,
            endOfToday: endOfToday,
            newPerDay: newPerDay,
            maxReviewsPerDay: maxReviewsPerDay,
            newIntroducedToday: newIntroducedToday,
            reviewsDoneToday: reviewsDoneToday
        )
    }

    /// Sum of per-deck allotments, unioning the scripts represented across all decks — the
    /// banner's aggregate total.
    static func aggregate(_ allowances: [DailyAllowance]) -> DailyAllowance {
        DailyAllowance(
            newCount: allowances.reduce(0) { $0 + $1.newCount },
            learnCount: allowances.reduce(0) { $0 + $1.learnCount },
            dueCount: allowances.reduce(0) { $0 + $1.dueCount },
            scripts: allowances.reduce(into: Set<Script>()) { $0.formUnion($1.scripts) }
        )
    }

    static func forDecks(
        _ decks: [Deck],
        now: Date,
        endOfToday: Date,
        newPerDay: Int = SRSConstants.defaultNewPerDay,
        maxReviewsPerDay: Int = SRSConstants.defaultMaxReviewsPerDay,
        newIntroducedToday: Int,
        reviewsDoneToday: Int
    ) -> DailyAllowance {
        aggregate(decks.map {
            forDeck(
                $0,
                now: now,
                endOfToday: endOfToday,
                newPerDay: newPerDay,
                maxReviewsPerDay: maxReviewsPerDay,
                newIntroducedToday: newIntroducedToday,
                reviewsDoneToday: reviewsDoneToday
            )
        })
    }
}
