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

    /// Number of distinct cards that entered the session at build time — the FIXED progress
    /// denominator. It does NOT grow when a card is re-queued after "Again", so a bar computed
    /// against it is monotonic and can never over-run 100%.
    let initialCount: Int

    /// Distinct cards the user has graded with anything OTHER than "Again" at least once this
    /// session — i.e. cards they've got right at least once, whether or not the card has fully
    /// graduated yet (new cards take several learning steps to graduate, so "graduated" would keep
    /// the bar at 0 through the whole first pass). This is the progress numerator.
    private var completedCardIDs: Set<UUID> = []

    /// Progress numerator: distinct cards graded non-"Again" at least once. Monotonic, never
    /// advances on "Again".
    var completedCount: Int {
        completedCardIDs.count
    }

    init(entries: [QueueEntry]) {
        self.entries = entries
        initialCount = entries.count
    }

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
        let reviewAllowance = DailyAllowance.remainingAllowance(cap: maxReviewsPerDay, doneToday: reviewsDoneToday)
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
        let newAllowance = DailyAllowance.remainingAllowance(cap: newPerDay, doneToday: newIntroducedToday)
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

    /// The card to show next, or nil when the session is finished.
    /// Returns the first entry in queue order whose `dueAt` is nil (new) or <= now.
    /// If no entry is currently due but entries remain, returns the earliest-due entry (early serve).
    /// Returns nil only when empty.
    func next(now: Date) -> QueueEntry? {
        guard !entries.isEmpty else { return nil }

        if let firstDue = entries.first(where: { entry in
            entry.snapshot.dueAt == nil || entry.snapshot.dueAt ?? now <= now
        }) {
            return firstDue
        }

        return entries.min { lhs, rhs in
            (lhs.snapshot.dueAt ?? now) < (rhs.snapshot.dueAt ?? now)
        }
    }

    /// Record the post-grade snapshot for a card and update the live queue.
    /// Removes the entry with `id` (no-op if not found).
    /// If the new state is `.learning` or `.relearning`, appends a new entry so the card re-enters the queue.
    /// If the new state is `.review`, the card leaves the session for good.
    mutating func markGraded(_ id: UUID, grade: Grade, newSnapshot: ScheduleSnapshot, now _: Date) {
        let wasPresent = entries.contains { $0.id == id }
        entries.removeAll { $0.id == id }

        if newSnapshot.state == .learning || newSnapshot.state == .relearning {
            // Re-queued so the card is shown again this session (learning step or a lapse).
            entries.append(QueueEntry(id: id, snapshot: newSnapshot))
        }

        // Progress counts a card as done once it's graded anything but "Again" — you got it right at
        // least once — even if it hasn't fully graduated. "Again" never advances the bar. Distinct,
        // so re-grading an already-counted card doesn't double-count.
        if wasPresent, grade != .again {
            completedCardIDs.insert(id)
        }
    }

    /// True when the queue is empty (no entries remain).
    var isFinished: Bool {
        entries.isEmpty
    }
}
