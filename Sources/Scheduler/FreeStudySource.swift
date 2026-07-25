import Foundation

/// Pure, endless card source for Free Study (idea #8 Part B): serves only previously-seen cards
/// (`CardState != .new`), shuffled from an injected RNG, and reshuffles-and-continues once the
/// pool is exhausted so callers can keep pulling cards indefinitely. Foundation-only, no
/// SwiftData, no wall clock — mirrors `SessionQueue`'s style. Completely decoupled from the SRS:
/// it never reads due dates and the caller must never persist anything from it.
struct FreeStudySource {
    /// The seen pool: only `.learning`, `.review`, and `.relearning` cards, in the order given.
    private let pool: [QueueEntry]
    private var upcoming: [QueueEntry] = []

    /// `entries` is the deck's full card list; cards with `state == .new` are excluded from the
    /// pool so Free Study never surfaces a card the user hasn't seen yet.
    init(entries: [QueueEntry], rng: inout some RandomNumberGenerator) {
        pool = entries.filter { $0.snapshot.state != .new }
        upcoming = pool.shuffled(using: &rng)
    }

    /// True when the deck has no previously-seen cards — the caller should show a caught-up /
    /// empty state rather than start a Free Study session.
    var isEmpty: Bool {
        pool.isEmpty
    }

    /// The next card in the endless shuffled sequence, or `nil` only when the pool itself is
    /// empty. Reshuffles and continues once the current shuffle is exhausted.
    mutating func next(rng: inout some RandomNumberGenerator) -> QueueEntry? {
        guard !pool.isEmpty else { return nil }
        if upcoming.isEmpty {
            upcoming = pool.shuffled(using: &rng)
        }
        return upcoming.removeFirst()
    }
}
