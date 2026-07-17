import Foundation

// Note: `QueueEntry` and `SessionQueue` are Sendable as the spec requires — but the conformance is
// left implicit rather than written out. Both are internal structs whose stored members are all
// Sendable, so Swift infers Sendable, and the DoD's SwiftFormat `redundantSendable` rule forbids
// spelling out the redundant annotation.

/// One card's identity plus its current schedule state, as fed to / emitted by the queue builder.
struct QueueEntry: Equatable {
    let id: UUID
    var snapshot: ScheduleSnapshot
}

/// Pure session-queue builder (docs/03-srs-algorithm.md §5).
///
/// Given a card pool and the day boundaries, produces the ordered study queue for a session:
/// due learning first, then due reviews (capped by the daily review allowance) interleaved with
/// new cards (capped by the daily new allowance), reviews weighted first. No SwiftData, no wall
/// clock — the caller supplies `now` and the 4 AM-adjusted `endOfToday`.
struct SessionQueue {
    private(set) var entries: [QueueEntry]

    /// Entries whose state is `.new`.
    var newCount: Int {
        entries.count(where: { $0.snapshot.state == .new })
    }

    /// Entries whose state is `.learning` or `.relearning`.
    var learnCount: Int {
        entries.count(where: { $0.snapshot.state == .learning || $0.snapshot.state == .relearning })
    }

    /// Entries whose state is `.review`.
    var dueCount: Int {
        entries.count(where: { $0.snapshot.state == .review })
    }

    static func build(
        cards: [QueueEntry],
        now: Date,
        endOfToday: Date,
        newPerDay: Int = SRSConstants.defaultNewPerDay,
        maxReviewsPerDay: Int = SRSConstants.defaultMaxReviewsPerDay,
        newIntroducedToday: Int,
        reviewsDoneToday: Int
    ) -> SessionQueue {
        // (1) Due learning/relearning: dueAt != nil && dueAt <= now, sorted by dueAt ascending.
        let learning = cards
            .filter { entry in
                (entry.snapshot.state == .learning || entry.snapshot.state == .relearning)
                    && entry.snapshot.dueAt.map { $0 <= now } == true
            }
            .sorted { lhs, rhs in
                // Both dueAt are non-nil here (filtered above).
                (lhs.snapshot.dueAt ?? now) < (rhs.snapshot.dueAt ?? now)
            }

        // (2) Due reviews: dueAt != nil && dueAt <= endOfToday, sorted by dueAt ascending,
        //     then capped by the remaining daily review allowance.
        let reviewAllowance = max(0, maxReviewsPerDay - reviewsDoneToday)
        let reviews = cards
            .filter { entry in
                entry.snapshot.state == .review
                    && entry.snapshot.dueAt.map { $0 <= endOfToday } == true
            }
            .sorted { lhs, rhs in
                (lhs.snapshot.dueAt ?? endOfToday) < (rhs.snapshot.dueAt ?? endOfToday)
            }
            .prefix(reviewAllowance)

        // (3) New cards: kept in the given input order, then capped by the remaining new allowance.
        let newAllowance = max(0, newPerDay - newIntroducedToday)
        let newCards = cards
            .filter { $0.snapshot.state == .new }
            .prefix(newAllowance)

        // (4) Interleave reviews and new ("reviews weighted first"): deterministic
        //     fractional-position merge, review wins ties.
        let merged = interleave(reviews: Array(reviews), new: Array(newCards))

        return SessionQueue(entries: learning + merged)
    }

    /// Deterministic fractional-position merge. Review at index i (R total) gets key (i+1)/(R+1);
    /// new at index j (N total) gets key (j+1)/(N+1). Sort ascending by key; review wins ties.
    private static func interleave(reviews: [QueueEntry], new: [QueueEntry]) -> [QueueEntry] {
        let reviewTotal = reviews.count
        let newTotal = new.count

        struct Keyed {
            let entry: QueueEntry
            let key: Double
            let isReview: Bool
            let index: Int
        }

        var keyed: [Keyed] = []
        keyed.reserveCapacity(reviewTotal + newTotal)
        for (i, entry) in reviews.enumerated() {
            keyed.append(Keyed(entry: entry, key: Double(i + 1) / Double(reviewTotal + 1), isReview: true, index: i))
        }
        for (j, entry) in new.enumerated() {
            keyed.append(Keyed(entry: entry, key: Double(j + 1) / Double(newTotal + 1), isReview: false, index: j))
        }

        keyed.sort { lhs, rhs in
            if lhs.key != rhs.key { return lhs.key < rhs.key }
            // Tie: reviews win.
            if lhs.isReview != rhs.isReview { return lhs.isReview }
            // Same type at equal key: preserve original relative order.
            return lhs.index < rhs.index
        }

        return keyed.map(\.entry)
    }
}
