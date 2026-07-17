# Kakitori — Content & Data

Kakitori does **not** bundle its own character database. Content arrives as Anki `.apkg`
files produced by the companion **anki-builder** pipeline
(`~/Development/anki-builder`), which generates decks from source material (e.g. *Japanese
for Busy People*) complete with recorded audio and translations.

Planned v1 content: a **kana deck** (already produced:
`anki-builder/output/epubs/japanese-for-busy-people-book-1-kana/deck-v5.apkg`) and a **kanji
deck** (same format, to be produced).

## 1. The `.apkg` contract

An `.apkg` is a zip archive:

```
deck.apkg
├── collection.anki2   # SQLite database (schema v11)
├── media              # JSON: { "0": "bc4e77e6407e004b.mp3", ... }
├── 0, 1, 2, ...       # media payloads, named by manifest key
```

Relevant tables in `collection.anki2`:

- `col` — single row; `models` and `decks` columns hold JSON blobs describing note types
  and the deck tree.
- `notes` — the content. `flds` holds field values joined by `\x1f` (US separator);
  `mid` links to the model.
- `cards`, `revlog`, `graves` — Anki scheduling/history. **Ignored on import** (Kakitori
  schedules itself; see [03-srs-algorithm.md](03-srs-algorithm.md)).

### 1.1 Expected note model: `AnkiBuilder`

| # | Field | Example | Kakitori use |
|---|---|---|---|
| 0 | `Target` | おはようございます。 | The text the user must **write**. Answer reveal. |
| 1 | `Pronunciation` | `ohayō gozai masu .` | Romaji reading — Recall prompt, answer reveal. |
| 2 | `English` | Good morning. | Translate & Write prompt, answer reveal. |
| 3 | `Category` | Greetings | Grouping/filtering within a deck. |
| 4 | `Hint` | (often empty) | Optional hint line under the prompt. |
| 5 | `Image` | (often empty) | Optional prompt illustration (future). |
| 6 | `Audio` | `[sound:bc4e77e6407e004b.mp3]` | Listen & Write prompt + answer playback. |

The importer matches fields **by name**, not index, so field reordering in anki-builder is
safe. Unknown fields are ignored; missing optional fields degrade gracefully (e.g. a note
with no `Audio` is excluded from Listen & Write sessions).

The model's own templates (Recognition/Production) and CSS are ignored — Kakitori renders
natively.

### 1.2 Deck tree → Kakitori decks

Anki uses `::`-separated names:

```
Japanese for Busy People Book 1: Kana
Japanese for Busy People Book 1: Kana::Frequently Used Expressions
Japanese for Busy People Book 1: Kana::Lesson 1: Meeting: Nice to Meet You
```

Import maps the **top-level deck** to one Kakitori deck, and each subdeck to a **section**
within it (displayed as a grouping, selectable for focused study later). The Anki "Default"
deck is skipped when empty.

## 2. Import pipeline (in-app)

1. User picks an `.apkg` via the Files picker (`UTType` registered for `.apkg`), or via
   share-sheet "Open in Kakitori".
2. Unzip to a temp directory (`collection.anki2` + `media` manifest + payload files).
3. Open the SQLite DB read-only; parse `col.models` + `col.decks`; read `notes`.
4. Validate: at least one model containing a `Target` field; ≥1 note. Reject otherwise with
   a clear error.
5. For each note: split `flds` on `\x1f`, map by field name, strip HTML, extract
   `[sound:...]` filenames from `Audio`.
6. Copy referenced media into the app's Application Support directory
   (`Media/<deckUUID>/<filename>`), renaming per the manifest.
7. Upsert into SwiftData: `Deck`, `Section`, `Note` rows; create one `CardSchedule` per note
   in state `new`.
8. **Re-import** of the same deck (matched by top-level deck name): update note content and
   media, add new notes as `new`, keep existing scheduling state, soft-delete notes that
   disappeared. Field edits never reset progress.

Everything happens on-device; no network involved.

## 3. Writing-specific derived data

The source decks are recognition-oriented; Kakitori derives what writing practice needs at
import time:

- **Guide boxes**: `Target` is segmented into writeable units (one box per character).
  Punctuation (。、！？・ー) renders in-line between boxes but gets no box — you practice
  characters, not full stops. Long phrases wrap across rows of boxes.
- **Trace guides**: each character is rendered as a faded glyph in a textbook font
  (system `HiraMinProN` or bundled Kyōkashō-style font) inside its box. v1 traces static
  glyphs; stroke-order animation (KanjiVG data) is a future enhancement, likely delivered
  through anki-builder as an extra field.
- **Script classification**: each note is tagged hiragana / katakana / kanji / mixed by
  Unicode range scan of `Target`, enabling per-script filtering and stats.

## 4. Audio

- **Primary**: the recorded MP3s shipped in the deck (`AVAudioPlayer`).
- **Fallback**: if a note lacks audio, `AVSpeechSynthesizer` (ja-JP) reads `Target`.
  Listen & Write prefers real recordings and only falls back when necessary.
- Playback: autoplay on card entry in Listen & Write (setting), tap-to-replay always, replay
  available on the answer reveal in every mode.

## 5. Storage layout

```
Application Support/Kakitori/
├── Kakitori.store              # SwiftData store (decks, notes, schedules, stats)
└── Media/
    └── <deckUUID>/*.mp3        # imported media, manifest-renamed
```

- Backed up by iCloud device backup by default (progress is precious).
- Media is content-addressable enough via filenames (anki-builder already hashes); re-import
  overwrites by name.

## 6. Content roadmap

| Deck | Source | Status |
|---|---|---|
| Kana (JBP Book 1) | anki-builder, deck-v5 | ✅ produced |
| Kanji (starter) | anki-builder | ⏳ to be produced |
| Vocabulary decks | anki-builder | future |

Because the app consumes a generic `.apkg` + `AnkiBuilder`-model contract, new content
requires **zero app changes** — build the deck, import it. Changes to the note model should
stay additive (new optional fields) to preserve that property.
