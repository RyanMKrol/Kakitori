# Kakitori — Roadmap

## Build order (v1)

Milestones are ordered so the riskiest/most-foundational pieces land first, and every
milestone ends with something runnable.

### M0 — Project bones
- Xcode project, Swift 6, iOS 18 target, SwiftData store wired.
- Design tokens (palette, type) + a Home screen showing hardcoded sample decks.
- ✅ Done when: app builds and shows the Home shell on iPad simulator.

### M1 — Canvas spike (risk first)
- PencilKit canvas with guide boxes, undo/clear, trace layer with faded glyphs.
- Tune ink feel on real iPad + Pencil hardware.
- ✅ Done when: tracing あ over a faded guide feels good in hand. This gate matters — if the
  writing feel is wrong, nothing else matters.

### M2 — Importer
- `.apkg` unzip, `collection.anki2` parsing, AnkiBuilder-model mapping, media copy,
  segmentation, SwiftData upsert, re-import idempotence.
- Fixture tests using the real kana deck (`deck-v5.apkg`).
- ✅ Done when: importing the JBP kana deck shows it on Home with correct counts/sections.

### M3 — Scheduler + session loop
- `SM2Scheduler` + `SessionQueue` with full unit-test coverage (docs/03).
- Session screen: Trace mode end to end — prompt, canvas, reveal, grade, next; summary
  screen; daily stats + streak.
- ✅ Done when: a full Trace session against the kana deck schedules correctly across days
  (verified via tests + a time-travel debug menu).

### M4 — Remaining modes + audio
- Listen & Write (deck MP3s + TTS fallback), Translate & Write, Recall.
- Mode availability rules; new-cards-always-trace-first rule.
- ✅ Done when: all four modes work against the kana deck.

### M5 — Polish & ship-readiness
- iPhone layouts, dark mode, Dynamic Type & VoiceOver pass, Reduce Motion.
- Settings (new/day, review cap, autoplay, romaji toggle).
- Empty states, import errors, app icon.
- Axiom audit pass (accessibility, swiftui-performance, memory) before TestFlight.
- ✅ Done when: TestFlight build in daily personal use.

### Content (parallel, in anki-builder)
- Produce the **kanji starter deck** in the same AnkiBuilder model.
- Keep the note model additive (docs/04 §6).

## Post-v1 ideas (unordered, uncommitted)

- **Stroke-order data**: KanjiVG-derived stroke animations for guides; possibly delivered as
  an extra anki-builder field.
- **Auto-scoring**: on-device handwriting recognition to sanity-check what was written
  (assistive feedback only — self-grading stays authoritative).
- **Per-mode scheduling** (docs/03 §8) and **FSRS**.
- **Handwriting history**: persist drawings; "your あ over 30 days" progress strip.
- **iCloud sync** (SwiftData + CloudKit) once the schema is stable.
- **Widgets**: due-count + streak on the Home Screen; maybe a "first card of the day" widget.
- **Focused study**: per-section (lesson) sessions; cram mode ignoring the scheduler.
- **macOS** via Catalyst or native, if trackpad/tablet input proves usable.

## Open questions

- Guide font: is Hiragino Mincho close enough to handwritten forms (esp. き, さ, ふ), or do
  we need a Kyōkashō font before M1 sign-off?
- Should Listen & Write hide even the box count (it leaks answer length)? v1 shows boxes;
  revisit after real use.
- Kanji deck granularity: character-level cards, word-level, or both? Decide when building
  the deck in anki-builder.
