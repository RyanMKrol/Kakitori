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
    }

    struct SessionSummary: Equatable {
        let gradeCounts: [Grade: Int]
        let cardsWritten: Int
        let seconds: Int
    }

    private(set) var phase: Phase = .prompt
    private(set) var currentNote: Note?
    private(set) var gradeCounts: [Grade: Int] = [:]
    private(set) var cardsWritten = 0
    private(set) var summary: SessionSummary?
    private(set) var lastError: Error?
    private(set) var presentedMode: PracticeMode = .trace

    let mode: PracticeMode
    let deckName: String
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

    var newCount: Int {
        queue.newCount
    }

    var learnCount: Int {
        queue.learnCount
    }

    var dueCount: Int {
        queue.dueCount
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
        self.modelContext = modelContext
        self.clock = clock
        self.audio = audio
        rng = SplitMix64(seed: seed)

        let deckScripts = Set(deck.sections.flatMap(\.notes).compactMap { !$0.isDeleted ? $0.script : nil })
        let availableModes = ModeAvailability.deckModes(scripts: deckScripts).filter { $0 != .mixed }
        modeResolver = ModeResolver(sessionMode: mode, availableModes: availableModes)

        let now = clock.now()
        sessionStart = now

        let notes = deck.sections.flatMap(\.notes).filter { !$0.isDeleted }
        var entries: [QueueEntry] = []
        var notesByID: [UUID: Note] = [:]
        entries.reserveCapacity(notes.count)
        for note in notes {
            guard let schedule = note.schedule else { continue }
            guard ModeAvailability.cardQualifies(
                mode,
                hasAudio: note.audioFilename != nil,
                ttsAvailable: audio.isAvailable,
                english: note.english
            ) else { continue }
            entries.append(QueueEntry(id: note.id, snapshot: Self.snapshot(from: schedule)))
            notesByID[note.id] = note
        }
        self.notesByID = notesByID

        let today = clock.adjustedDay(for: now)
        let todayStats = Self.fetchDailyStats(for: today, in: modelContext)
        let endOfToday = Self.endOfToday(after: now, using: clock)

        queue = SessionQueue.build(
            cards: entries,
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
            autoplayOnCardEntry()
        }
    }

    func showAnswer() {
        guard phase == .prompt else { return }
        phase = .revealed
    }

    func replayAudio() {
        guard let note = currentNote, let deckID = note.deck?.id else { return }
        audio.play(target: note.target, audioFilename: note.audioFilename, deckID: deckID)
    }

    func grade(_ grade: Grade) {
        guard phase == .revealed, let currentEntry, let note = currentNote, let schedule = note.schedule else {
            return
        }

        let now = clock.now()
        let previousState = currentEntry.snapshot.state
        let newSnapshot = scheduler.apply(grade, to: currentEntry.snapshot, now: now, rng: &rng)
        applySnapshot(newSnapshot, to: schedule)

        do {
            try StatsRecorder.recordGrade(previousState: previousState, now: now, in: modelContext)
        } catch {
            lastError = error
        }

        gradeCounts[grade, default: 0] += 1
        cardsWritten += 1

        queue.markGraded(currentEntry.id, newSnapshot: newSnapshot, now: now)

        if let nextEntry = queue.next(now: now) {
            self.currentEntry = nextEntry
            currentNote = notesByID[nextEntry.id]
            updatePresentedMode()
            phase = .prompt
            hasAutoplayed = false
            autoplayOnCardEntry()
        } else {
            finish(now: now)
        }
    }

    func close() {
        guard phase != .finished else { return }

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
            try StatsRecorder.recordStudySeconds(seconds, now: now, in: modelContext)
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

    private static func fetchDailyStats(for day: String, in context: ModelContext) -> DailyStats? {
        var descriptor = FetchDescriptor<DailyStats>(predicate: #Predicate { $0.day == day })
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

        guard let currentEntry else {
            presentedMode = .trace
            return
        }

        presentedMode = modeResolver.nextMode(cardState: currentEntry.snapshot.state, qualifies: qualifies)
    }

    private func autoplayOnCardEntry() {
        guard !hasAutoplayed, presentedMode == .listen, autoplayEnabled else { return }
        hasAutoplayed = true
        replayAudio()
    }
}
