# Kakitori — Architecture

## 1. Stack

| Concern | Choice | Notes |
|---|---|---|
| Language | Swift 6 | strict concurrency on |
| UI | SwiftUI | `@Observable` models, NavigationStack |
| Writing canvas | PencilKit (`PKCanvasView` via `UIViewRepresentable`) | finger + Pencil |
| Persistence | SwiftData | single on-device store |
| Deck import | SQLite3 (system C library) + `Foundation` zip handling | read-only access to `collection.anki2` |
| Audio | AVAudioPlayer (deck MP3s), AVSpeechSynthesizer (fallback) | |
| Min deployment | iOS 18 / iPadOS 18 | universal app, iPad-first layout |
| Testing | XCTest | scheduler + importer are the high-value targets; XCTest (not Swift Testing) for consistency with the team's sibling harness projects — decided at harness setup |

No third-party dependencies in v1. If raw SQLite proves painful, GRDB is the sanctioned
escape hatch (already covered by project tooling/audits).

## 2. Module layout (single Xcode project, folder = target group)

```
Kakitori/
├── App/                    # @main, root scene, DI wiring
├── Models/                 # SwiftData @Model types
│   ├── Deck.swift          #   Deck, Section
│   ├── Note.swift          #   imported content
│   ├── CardSchedule.swift  #   SRS state (1:1 with Note in v1)
│   └── DailyStats.swift    #   per-day counters, streak source
├── Scheduler/              # pure logic, no imports beyond Foundation
│   ├── Scheduler.swift     #   protocol Scheduler
│   ├── SM2Scheduler.swift  #   v1 implementation (docs/03)
│   └── SessionQueue.swift  #   queue building + in-session re-entry
├── Importer/
│   ├── ApkgImporter.swift  #   unzip → validate → upsert (docs/04 §2)
│   ├── AnkiCollection.swift#   SQLite reading, models/decks JSON
│   └── TargetSegmenter.swift # Target → guide-box units, script classification
├── Audio/
│   └── AudioService.swift  #   deck MP3 playback + TTS fallback
├── Features/
│   ├── Home/               #   dashboard, deck list, stats row
│   ├── DeckSetup/          #   mode picker sheet
│   ├── Session/            #   session VM, prompt pane, answer, grading
│   │   └── Canvas/         #   PKCanvasView wrapper, guide boxes, trace layer
│   └── Summary/            #   session complete screen
└── Support/                # design tokens, extensions, previews data
```

**Dependency rule:** `Features → (Models, Scheduler, Importer, Audio) → Foundation`.
`Scheduler` and `Importer` know nothing about SwiftUI; both are unit-testable headless.

## 3. Data model (SwiftData)

```
Deck        1 ──── * Section       1 ──── * Note        1 ──── 1 CardSchedule
                                            │
DailyStats (standalone, keyed by adjusted day)
```

```swift
@Model final class Deck {
    var id: UUID
    var name: String            // top-level Anki deck name
    var jpTitle: String?        // display override (e.g. ひらがな)
    var sourceDeckName: String  // re-import matching key
    var importedAt: Date
    var sections: [Section]
}

@Model final class Note {
    var id: UUID
    var target: String          // text to write
    var pronunciation: String?
    var english: String?
    var category: String?
    var hint: String?
    var audioFilename: String?  // relative to Media/<deckUUID>/
    var script: Script          // hiragana | katakana | kanji | mixed
    var units: [String]         // segmented writeable characters
    var isDeleted: Bool         // soft delete on re-import
    var section: Section?
    var schedule: CardSchedule?
}

@Model final class CardSchedule {
    var state: CardState        // new | learning | review | relearning
    var stepIndex: Int
    var easeFactor: Double
    var intervalDays: Double
    var dueAt: Date?
    var lapses: Int
    var note: Note?
}

@Model final class DailyStats {
    var day: String             // "YYYY-MM-DD" of the 4am-adjusted day
    var cardsWritten: Int
    var newIntroduced: Int
    var reviewsDone: Int
    var secondsStudied: Int
}
```

## 4. Scheduler isolation

```swift
protocol Scheduler {
    /// Intervals each grade would produce — used for button previews.
    func preview(for card: ScheduleSnapshot, now: Date) -> [Grade: SchedulePreview]
    /// Apply a grade, returning the new snapshot (pure function).
    func apply(_ grade: Grade, to card: ScheduleSnapshot, now: Date) -> ScheduleSnapshot
}
```

`ScheduleSnapshot` is a plain value struct mirroring `CardSchedule` — the scheduler never
touches SwiftData. The session view model reads a snapshot, calls the scheduler, writes the
result back. This is what makes an FSRS swap (docs/03 §8) a one-file change, and what makes
the scheduler exhaustively unit-testable.

## 5. Session flow (runtime)

```
DeckSetupView ──(deck, mode)──▶ SessionViewModel
    SessionQueue.build(deck, limits, now)      // fetch due/new via SwiftData
    loop:
        card = queue.next(now)
        SessionView renders prompt(mode, note) + CanvasView(units, guides: mode == .trace)
        user writes → "Show answer" → answer block + grade buttons (scheduler.preview)
        grade → scheduler.apply → persist CardSchedule + DailyStats → queue.reinsertIfSubDay
    queue empty ──▶ SummaryView(sessionStats)
```

- `SessionViewModel` is `@Observable`, `@MainActor`. All SwiftData access happens on the
  main actor in v1 (data volumes are tiny; no background contexts needed).
- Canvas: one `PKCanvasView` sized to the row(s) of guide boxes; guide glyphs are drawn in a
  `Canvas`/image layer *behind* it. Undo uses `PKCanvasView.undoManager`; Clear sets an
  empty `PKDrawing`.
- The drawing is discarded after grading (not persisted) in v1. Persisting drawings for a
  "review your handwriting" history is a listed future idea.

## 6. Import flow (runtime)

```
Files picker / .apkg open-in
  → ApkgImporter.import(url)        // background task, progress reported
      unzip → AnkiCollection(sqlite) → notes → TargetSegmenter → upsert models + copy media
  → Home refreshes via SwiftData observation
```

Import runs off-main (the importer is an `actor`); UI shows determinate progress for media
copying. Errors surface as an alert with a specific reason (bad zip, no AnkiBuilder-model,
zero notes).

## 7. Testing strategy

| Layer | Approach |
|---|---|
| `SM2Scheduler` | pure unit tests: every grade × state transition, clamps, fuzz bounds, button previews match applied results |
| `SessionQueue` | unit tests: limits, ordering, sub-day re-entry, empty-queue early serve |
| `ApkgImporter` | fixture tests against a small checked-in `.apkg` (built by anki-builder); re-import idempotence; progress preservation |
| `TargetSegmenter` | table tests: kana, kanji, mixed, punctuation, long-phrase wrapping |
| UI | light smoke tests only in v1; manual testing on iPad hardware for canvas feel |

## 8. Known risks

- **PencilKit feel** — ink defaults may feel un-brush-like; budget tuning time early
  (spike in milestone 1, see roadmap).
- **`\x1f` field parsing / HTML in fields** — anki-builder output is clean today, but strip
  HTML defensively; a malformed deck must fail import, not corrupt state.
- **Long phrases on iPhone** — the iPhone prototype shows a single guide box; the kana deck
  is phrase-level (10+ characters). The ≤4-boxes-per-row wrapping in docs/06 §2.3 is
  designed but unproven on a phone canvas — validate during M1/M5.
