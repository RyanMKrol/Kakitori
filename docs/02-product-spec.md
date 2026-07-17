# Kakitori — Product Specification

This spec describes v1 behaviour end to end. The HTML prototype in `../reference/` is the
source of truth for look and feel; where this document and the prototype disagree on
behaviour, this document wins.

## 1. Screens

```
Home (dashboard + deck list)
 └─ Deck setup sheet (mode picker)
     └─ Practice session (full screen)
         └─ Session summary
```

### 1.1 Home

The single hub screen. Contains:

- **Header**: app mark (書), app name, tagline ("Write your Japanese, card by card").
- **Stats row** (today):
  - 🔥 Day streak — consecutive days with ≥1 completed card.
  - Written today — cards completed today across all decks.
  - Minutes studied today.
- **Today's practice banner**: total due cards across all decks
  ("N characters to write · across M scripts").
- **Deck list**: one card per deck showing:
  - Japanese title (e.g. ひらがな), English title (Hiragana), subtitle (e.g. "46 base + dakuten"),
  - overall mastery % (see §4.4),
  - due-count chips: `new` / `learning` / `due`,
  - a **Study →** button.

Tapping a deck (or Study) opens the **deck setup sheet**.

### 1.2 Deck setup sheet

A modal sheet over Home:

- Deck name + total cards due in this session.
- **Practice mode picker** — one option per mode (§2), each with a Japanese glyph, label, and
  one-line description. Modes that don't apply to the deck are hidden (see §2.5).
- **Start writing** button → launches the session.

### 1.3 Practice session (full screen)

Two-pane layout (side by side on iPad/landscape, stacked prompt-above-canvas on iPhone/portrait):

- **Top bar**: close (✕), deck name, mode label, progress bar with "X done · Y left",
  remaining-count chips (`new` / `learn` / `due`).
- **Prompt pane** (left): mode-specific prompt (§2). After reveal, shows the **answer block**:
  target character(s) large, reading, English meaning, example (when available), play-audio
  button.
- **Canvas pane** (right): writing area with one guide box per character to write
  (genkō yōshi-style box with dashed centre cross-lines). Toolbar: **Undo**, **Clear**.
  A hint line above the boxes describes what to do in the current mode.
- **Action row** (below canvas):
  - Before reveal: **Show answer**.
  - After reveal: grade buttons **Again / Hard / Good / Easy**, each showing its resulting
    interval (e.g. "Again <1m", "Good 10m", "Easy 4d").

Session behaviour:

- Cards are served from the session queue (see [03-srs-algorithm.md](03-srs-algorithm.md) §5).
- Grading a card immediately advances to the next card and clears the canvas.
- Closing mid-session (✕) preserves all grades already given; ungraded cards stay due.

### 1.4 Session summary

Shown when the queue empties:

- 済 mark, "お疲れさま！", "Session complete — N cards written in M min".
- Grade breakdown counts (Again / Hard / Good / Easy).
- Streak line ("🔥 N day streak · keep it going tomorrow").
- Buttons: **Back to decks**, **Study another deck** (returns to Home with the setup sheet
  ready).

## 2. Practice modes

All modes end the same way: user writes on the canvas → **Show answer** → self-grade.
The modes differ only in the *prompt* and in whether guides appear in the canvas boxes.

### 2.1 Trace (なぞり)

- Prompt pane: "Write over the faded guides" + instruction text. The reading is shown.
- Canvas: each guide box contains the target character rendered as a **faded grey guide**;
  the user writes directly over it.
- Purpose: first exposure / motor learning. This is the default mode for `new` cards.

### 2.2 Listen & Write (聞き取り)

- Prompt pane: a large **play button**; audio of the reading plays automatically on card
  entry and on tap. No text shown before reveal.
- Canvas: empty boxes (no guides).
- Purpose: sound → writing mapping (true dictation, the classic 書き取り exercise).

### 2.3 Translate & Write (翻訳)

- Prompt pane: the **English** meaning ("Write this in Japanese").
- Canvas: empty boxes.
- Only available for cards that have a meaningful English gloss (kanji and word cards;
  hidden for bare kana decks — a kana has a sound, not a translation).

### 2.4 Recall (思い出し)

- Prompt pane: the **reading** (kana/romaji) and, when present, the English meaning in
  quotes. "Write the word from memory."
- Canvas: empty boxes.
- Purpose: the hardest production test; reading → written form.

### 2.5 Mode availability per deck type

| Mode | Kana decks | Kanji deck |
|---|---|---|
| Trace | ✓ | ✓ |
| Listen & Write | ✓ (plays the kana sound) | ✓ (plays the reading) |
| Translate & Write | ✗ (no gloss) | ✓ |
| Recall | ✓ (prompt = romaji) | ✓ (prompt = reading + meaning) |

## 3. Writing canvas

- Built on **PencilKit** (`PKCanvasView`), one drawing surface with N guide boxes overlaid.
- Input: Apple Pencil and finger both accepted (v1 does not restrict to Pencil).
- Ink: single black "pen" style, fixed width tuned to look brush-adjacent; no tool picker.
- **Undo** removes the last stroke; **Clear** empties the canvas (with no confirmation —
  it's cheap to rewrite).
- In Trace mode, guides are rendered *under* the canvas (separate layer), so Clear never
  removes guides.
- The canvas is never scored in v1. It exists for the user's own comparison against the
  revealed answer.

## 4. Progress, stats, and streaks

### 4.1 Card grading → scheduling

Grades feed the SRS scheduler; see [03-srs-algorithm.md](03-srs-algorithm.md).

### 4.2 Daily stats

Tracked per calendar day (device local time):

- `cardsWritten` — count of grades given.
- `secondsStudied` — accumulated active session time.

### 4.3 Streak

- A day counts if ≥1 card was graded that day.
- Streak = consecutive counting days ending today (or yesterday, if today has no activity
  yet — the streak isn't shown as broken until the day actually passes).

### 4.4 Deck mastery %

Shown on deck cards: `mature cards / total cards`, where a card is *mature* when its current
interval ≥ 21 days (Anki convention). Simple, honest, no weighting.

## 5. Settings (v1, minimal)

- New cards per day per deck (default 10).
- Max reviews per day per deck (default 100).
- Audio autoplay on/off for Listen & Write (default on).
- Romaji shown alongside kana readings on/off (default on; learners weaning off romaji can
  disable).

## 6. Non-goals for v1

- No accounts, no server, no sync.
- No automated stroke recognition or scoring.
- No custom/user-created decks.
- No notifications (revisit with widgets later).
- No iPhone-specific compact session layout beyond the stacked arrangement in §1.3.
