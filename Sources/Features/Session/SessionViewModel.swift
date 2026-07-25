import Foundation
import SwiftData

/// Owns a running practice session end-to-end: builds the queue, drives prompt → reveal →
/// grade, applies `SM2Scheduler`, persists `CardSchedule` + stats, and ends with a summary
/// (docs/05-architecture.md §5, docs/02-product-spec.md §1.3–§1.4).
@MainActor
@Observable
final class SessionViewModel {
    enum Phase: Equatable {
        case prompt
        case revealed
        case finished
        case caughtUp
    }

    struct SessionSummary: Equatable {
        let gradeCounts: [Grade: Int]
        let cardsWritten: Int
        let seconds: Int
    }

    private(set) var phase: Phase = .prompt
    private(set) var currentNote: Note?

    /// The note the answer block is showing. Set at reveal and deliberately NOT cleared when the
    /// card advances: leaving `.revealed` fades the answer block out over a beat, and if the block
    /// read `currentNote` the NEXT card's answer would render into it mid-fade and be readable for
    /// a fraction of a second — giving the answer away before the user has written anything. It
    /// changes again only on the next `showAnswer()`, by which point the block is fully invisible.
    private(set) var revealedNote: Note?
    private(set) var gradeCounts: [Grade: Int] = [:]
    private(set) var cardsWritten = 0
    private(set) var summary: SessionSummary?
    private(set) var lastError: Error?
    private(set) var presentedMode: PracticeMode = .trace

    let mode: PracticeMode
    let deckName: String
    private let deckKey: String
    var autoplayEnabled: Bool {
        (UserDefaults.standard.object(forKey: "audioAutoplay") as? Bool) ?? true
    }

    private let modelContext: ModelContext
    private let clock: AppClock
    private let scheduler = SM2Scheduler()
    private var rng: SplitMix64
    private let audio: any AudioPlaying

    private var queue: SessionQueue
    private var notesByID: [UUID: Note]
    private var currentEntry: QueueEntry?
    private let sessionStart: Date
    private var hasAutoplayed = false
    private var modeResolver: ModeResolver
    private let dailyStatsRow: DailyStats?

    /// True when this session is a Free Study session: SRS-decoupled, endless, never persists a
    /// `CardSchedule` change or a `DailyStats` write. See the dedicated Free Study initializer.
    let isFreeStudy: Bool
    private var freeStudySource: FreeStudySource?

    var newCount: Int {
        queue.newCount
    }

    var learnCount: Int {
        queue.learnCount
    }

    var dueCount: Int {
        queue.dueCount
    }

    /// The deck's progress toward TODAY's target (unified-progress). The in-session bar shows the
    /// SAME X/Y as the deck card and Home banner: `dayCompleted` (X) rises as cards are finished
    /// (graded anything but "Again", once per card per day), and `dayTarget` (Y) is the fixed daily
    /// target snapshotted at the start of the day. Study mode never affects these.
    private(set) var dayCompleted: Int = 0
    private(set) var dayTarget: Int = 0

    /// Progress numerator / denominator consumed by SessionView — the deck's day progress.
    var completedCount: Int {
        dayCompleted
    }

    var sessionCardCount: Int {
        dayTarget
    }

    /// Grade-preview labels for the current card, for the grading buttons (T033).
    var gradePreviews: [Grade: SchedulePreview] {
        guard let currentEntry else { return [:] }
        return scheduler.preview(for: currentEntry.snapshot, now: clock.now())
    }

    init(
        deck: Deck,
        mode: PracticeMode,
        modelContext: ModelContext,
        clock: AppClock,
        seed: UInt64,
        audio: any AudioPlaying = AudioService(),
        newPerDay: Int = SRSConstants.defaultNewPerDay,
        maxReviewsPerDay: Int = SRSConstants.defaultMaxReviewsPerDay
    ) {
        self.mode = mode
        deckName = deck.name
        deckKey = deck.sourceDeckName
        self.modelContext = modelContext
        self.clock = clock
        self.audio = audio
        rng = SplitMix64(seed: seed)
        isFreeStudy = false

        let deckScripts = Set(deck.sections.flatMap(\.notes).compactMap { !$0.isDeleted ? $0.script : nil })
        let availableModes = ModeAvailability.deckModes(scripts: deckScripts).filter { $0 != .mixed }
        modeResolver = ModeResolver(sessionMode: mode, availableModes: availableModes)

        let now = clock.now()
        sessionStart = now

        // Snapshot today's target for this deck (fixed at day start) and read what's already done
        // today, so the in-session bar shows the deck's day progress and we don't re-serve cards
        // already finished today. (unified-progress)
        let statsRow = try? StatsRecorder.ensureDailyStats(
            for: deck,
            now: now,
            newPerDay: newPerDay,
            maxReviewsPerDay: maxReviewsPerDay,
            in: modelContext
        )
        dailyStatsRow = statsRow
        dayTarget = statsRow?.dailyTarget ?? 0
        dayCompleted = statsRow?.completedToday ?? 0
        let completedTodayIDs = Set(statsRow?.completedCardIDs ?? [])

        let notes = deck.sections.flatMap(\.notes).filter { !$0.isDeleted }
        let built = Self.buildEntries(notes: notes, mode: mode, audio: audio, completedTodayIDs: completedTodayIDs)
        notesByID = built.notesByID

        let today = clock.adjustedDay(for: now)
        let todayStats = Self.fetchDailyStats(for: today, deckKey: deck.sourceDeckName, in: modelContext)
        let endOfToday = Self.endOfToday(after: now, using: clock)

        queue = SessionQueue.build(
            cards: built.entries,
            now: now,
            endOfToday: endOfToday,
            newPerDay: newPerDay,
            maxReviewsPerDay: maxReviewsPerDay,
            newIntroducedToday: todayStats?.newIntroduced ?? 0,
            reviewsDoneToday: todayStats?.reviewsDone ?? 0
        )

        if let firstEntry = queue.next(now: now) {
            currentEntry = firstEntry
            currentNote = notesByID[firstEntry.id]
            updatePresentedMode()
        } else {
            phase = .caughtUp
        }
    }

    /// Constructs the view model in Free Study mode (idea #8 Part B): a session completely
    /// decoupled from the SRS. It draws only previously-seen cards (`CardState != .new`) from
    /// `FreeStudySource`, shuffled and endless, and never reads or writes `CardSchedule` /
    /// `DailyStats` — the deck's daily target is left untouched. Ending is user-initiated
    /// (`close()`); Free Study never auto-finishes.
    init(
        freeStudyDeck deck: Deck,
        mode: PracticeMode,
        modelContext: ModelContext,
        clock: AppClock,
        seed: UInt64,
        audio: any AudioPlaying = AudioService()
    ) {
        self.mode = mode
        deckName = deck.name
        deckKey = deck.sourceDeckName
        self.modelContext = modelContext
        self.clock = clock
        self.audio = audio
        rng = SplitMix64(seed: seed)
        isFreeStudy = true

        let deckScripts = Set(deck.sections.flatMap(\.notes).compactMap { !$0.isDeleted ? $0.script : nil })
        let availableModes = ModeAvailability.deckModes(scripts: deckScripts).filter { $0 != .mixed }
        modeResolver = ModeResolver(sessionMode: mode, availableModes: availableModes)

        sessionStart = clock.now()

        // Free Study never touches the daily target or completion tracking — left inert.
        dailyStatsRow = nil
        dayTarget = 0
        dayCompleted = 0

        let notes = deck.sections.flatMap(\.notes).filter { !$0.isDeleted }
        let built = Self.buildEntries(notes: notes, mode: mode, audio: audio, completedTodayIDs: [])
        notesByID = built.notesByID

        // Unused in Free Study — the endless FreeStudySource drives card selection instead.
        queue = SessionQueue(entries: [])

        var source = FreeStudySource(entries: built.entries, rng: &rng)
        if let firstEntry = source.next(rng: &rng) {
            currentEntry = firstEntry
            currentNote = notesByID[firstEntry.id]
        } else {
            phase = .caughtUp
        }
        freeStudySource = source
        updatePresentedMode()
    }

    func showAnswer() {
        guard phase == .prompt, currentEntry != nil, currentNote != nil else { return }
        revealedNote = currentNote
        phase = .revealed
        triggerAutoplayOnReveal()
    }

    /// The revealed answer block offers a Play audio control; with "Audio autoplay" on, play it
    /// instead of making the user reach for it. Skipped when this card already auto-played — in
    /// Listen mode the audio IS the prompt, and revealing shouldn't fire a second burst.
    private func triggerAutoplayOnReveal() {
        guard autoplayEnabled, !hasAutoplayed else { return }
        hasAutoplayed = true
        replayAudio()
    }

    func replayAudio() {
        guard let note = currentNote, let deckID = note.deck?.id else { return }
        audio.play(target: note.target, audioFilename: note.audioFilename, deckID: deckID)
    }

    func grade(_ grade: Grade) {
        guard phase == .revealed, currentEntry != nil, currentNote != nil else {
            return
        }

        // Free Study's grading control is a single 'Next / Keep going' advance, not the four SRS
        // grade buttons — persist nothing and return before any scheduler/StatsRecorder call.
        if isFreeStudy {
            advanceFreeStudy()
            return
        }

        guard let currentEntry, let note = currentNote, let schedule = note.schedule else {
            return
        }

        let now = clock.now()
        let previousState = currentEntry.snapshot.state
        let newSnapshot = scheduler.apply(grade, to: currentEntry.snapshot, now: now, rng: &rng)
        applySnapshot(newSnapshot, to: schedule)

        do {
            try StatsRecorder.recordGrade(previousState: previousState, now: now, deckKey: deckKey, in: modelContext)
            // A non-"Again" grade finishes the card for the day — record it and advance the deck's
            // day progress (the source of truth for every progress bar). (unified-progress)
            if grade != .again {
                try StatsRecorder.recordCompletion(
                    cardID: currentEntry.id,
                    deckKey: deckKey,
                    now: now,
                    in: modelContext
                )
                dayCompleted = dailyStatsRow?.completedToday ?? dayCompleted
            }
        } catch {
            lastError = error
        }

        gradeCounts[grade, default: 0] += 1
        cardsWritten += 1

        queue.markGraded(currentEntry.id, grade: grade, newSnapshot: newSnapshot, now: now)

        // Finished the day's target → the session is done, even if the queue isn't literally empty.
        if dayTarget > 0, dayCompleted >= dayTarget {
            finish(now: now)
        } else if let nextEntry = queue.next(now: now) {
            self.currentEntry = nextEntry
            currentNote = notesByID[nextEntry.id]
            updatePresentedMode()
            phase = .prompt
            hasAutoplayed = false
        } else {
            finish(now: now)
        }
    }

    /// Free Study's advance path: pulls the next card from the endless `FreeStudySource` and
    /// persists nothing — no `scheduler.apply`, no `CardSchedule` mutation, no `StatsRecorder`
    /// call. `cardsWritten` is tracked in-memory only, for the session summary display.
    func advanceFreeStudy() {
        cardsWritten += 1
        guard let nextEntry = freeStudySource?.next(rng: &rng) else {
            currentEntry = nil
            currentNote = nil
            phase = .caughtUp
            return
        }
        currentEntry = nextEntry
        currentNote = notesByID[nextEntry.id]
        updatePresentedMode()
        phase = .prompt
        hasAutoplayed = false
    }

    func close() {
        guard phase != .finished, phase != .caughtUp else { return }
        guard !isFreeStudy else { return }

        let now = clock.now()
        recordStudySeconds(now: now)
    }

    private func finish(now: Date) {
        recordStudySeconds(now: now)
        summary = SessionSummary(
            gradeCounts: gradeCounts,
            cardsWritten: cardsWritten,
            seconds: Int(now.timeIntervalSince(sessionStart))
        )
        currentEntry = nil
        currentNote = nil
        phase = .finished
    }

    private func recordStudySeconds(now: Date) {
        let seconds = Int(now.timeIntervalSince(sessionStart))
        do {
            try StatsRecorder.recordStudySeconds(seconds, now: now, deckKey: deckKey, in: modelContext)
        } catch {
            lastError = error
        }
    }

    private func applySnapshot(_ snapshot: ScheduleSnapshot, to schedule: CardSchedule) {
        schedule.state = snapshot.state
        schedule.stepIndex = snapshot.stepIndex
        schedule.easeFactor = snapshot.easeFactor
        schedule.intervalDays = snapshot.intervalDays
        schedule.dueAt = snapshot.dueAt
        schedule.lapses = snapshot.lapses
    }

    /// Build the session's queue entries from a deck's notes: skip cards already finished today and
    /// cards that don't qualify for the chosen mode. Returns the entries plus an id→Note lookup.
    private static func buildEntries(
        notes: [Note],
        mode: PracticeMode,
        audio: any AudioPlaying,
        completedTodayIDs: Set<String>
    ) -> (entries: [QueueEntry], notesByID: [UUID: Note]) {
        var entries: [QueueEntry] = []
        var notesByID: [UUID: Note] = [:]
        entries.reserveCapacity(notes.count)
        for note in notes {
            guard let schedule = note.schedule else { continue }
            // Skip cards already finished today — they've had their turn; don't re-serve them.
            guard !completedTodayIDs.contains(note.id.uuidString) else { continue }
            guard ModeAvailability.cardQualifies(
                mode,
                hasAudio: note.audioFilename != nil,
                ttsAvailable: audio.isAvailable,
                english: note.english
            ) else { continue }
            entries.append(QueueEntry(id: note.id, snapshot: snapshot(from: schedule)))
            notesByID[note.id] = note
        }
        return (entries, notesByID)
    }

    private static func snapshot(from schedule: CardSchedule) -> ScheduleSnapshot {
        ScheduleSnapshot(
            state: schedule.state,
            stepIndex: schedule.stepIndex,
            easeFactor: schedule.easeFactor,
            intervalDays: schedule.intervalDays,
            dueAt: schedule.dueAt,
            lapses: schedule.lapses
        )
    }

    private static func fetchDailyStats(for day: String, deckKey: String?, in context: ModelContext) -> DailyStats? {
        var descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.day == day && $0.deckKey == deckKey }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// The next 4:00 AM local time at or after `now` (docs/03-srs-algorithm.md §7).
    private static func endOfToday(after now: Date, using clock: AppClock) -> Date {
        var components = clock.calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = SRSConstants.dayRolloverHour
        components.minute = 0
        components.second = 0
        guard let candidate = clock.calendar.date(from: components) else { return now }
        if candidate > now { return candidate }
        return clock.calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
    }

    private func updatePresentedMode() {
        guard let currentNote else {
            presentedMode = .trace
            return
        }

        let qualifies: (PracticeMode) -> Bool = { [weak self] mode in
            ModeAvailability.cardQualifies(
                mode,
                hasAudio: currentNote.audioFilename != nil,
                ttsAvailable: self?.audio.isAvailable ?? false,
                english: currentNote.english
            )
        }

        presentedMode = modeResolver.nextMode(qualifies: qualifies)
    }

    func triggerAutoplayOnCardAppearance() {
        // Auto-play the card's pronunciation on appearance only in Listen mode, where the audio IS the
        // prompt. NOT Trace — the user must explicitly tap replay. NOT Translate — there the prompt
        // is the English and auto-playing the Japanese reading would spoil it. Respects the "Audio
        // autoplay" setting.
        let autoplayMode = presentedMode == .listen
        guard !hasAutoplayed, autoplayEnabled, autoplayMode else { return }
        hasAutoplayed = true
        replayAudio()
    }
}
