# Kakitori — UI Design

The HTML prototype (`../reference/Kaki - Kana Writing Practice.dc.html`) and its screenshots
(`../reference/screenshots/`) define the visual direction. This doc translates it into an
iOS design language.

## 1. Visual language

**Feel: quiet stationery.** Paper, ink, one accent. No cards-with-glows, no confetti.

### Palette

| Token | Value (light) | Use |
|---|---|---|
| `paper` | warm off-white `#FAF8F4` | app background |
| `ink` | near-black `#1A1A1A` | text, user strokes |
| `inkFaint` | 12% ink | guide glyphs in Trace mode |
| `accent` | vermillion red `#C43B2E` (hanko red) | mode labels, ANSWER caption, primary buttons, streak |
| `boxLine` | 8% ink | guide box borders + dashed cross lines |
| `chipNew` / `chipLearn` / `chipDue` | neutral fill / red-tint fill / ink fill | count chips (matches prototype) |

Dark mode: `paper → #17150F`-ish warm near-black, ink inverts, accent stays. Design for
light first (paper is the identity); verify dark before ship.

### Typography

- UI text: system (SF Pro), generous tracking on small caps labels ("TRACE MODE", "ANSWER").
- Japanese display (answers, guides, deck titles): **Hiragino Mincho ProN** (system serif —
  textbook-adjacent). Revisit a bundled Kyōkashō font later for stroke-accurate guide shapes.
- Big answer glyphs: ~64–96pt depending on unit count.

### Shape & depth

- Cards/sheets: large radius (16–20pt), hairline borders, minimal shadow.
- The prototype's framed dark bezel is an artifact of its mock; the app itself is edge-to-edge
  paper.

## 2. Screen specs

### 2.1 Home

- **Stats row**: three inline stats (streak / written today / minutes). Small caps captions,
  large numerals.
- **Today banner**: full-width tinted card. "N characters to write · across M scripts".
- **Deck cards**: JP title large (ひらがな), EN title + subtitle small, mastery % right-aligned,
  chips row (`3 new · 3 learning · 4 due`), Study button. One column on iPhone, 2-up grid on
  iPad.
- Empty state (no decks yet): 書 mark + "Import a deck to start writing" + Import button →
  Files picker. Import also lives behind a toolbar `+`.

### 2.2 Deck setup sheet

- Native sheet, medium detent on iPhone, formSheet on iPad.
- Header: deck JP + EN name, "N cards due".
- Mode list: one row per available mode — leading Japanese glyph (書 / 聞 / 訳 / 思), label,
  one-line description, selection ring. Unavailable modes hidden (docs/02 §2.5).
- Primary button pinned at bottom: **Start writing**.

### 2.3 Session screen

Layout (iPad / landscape) — matches screenshots:

```
┌──────────────────────────────────────────────────────────────┐
│ ✕  Hiragana Basics      ▓▓▓░░░░░░  0 done · 10 left   chips  │
├──────────────────────┬───────────────────────────────────────┤
│                      │  Trace each character in its box      │
│      TRACE MODE      │                        [↶ Undo][Clear]│
│   Write over the     │   ┌─────┐ ┌─────┐ ┌─────┐             │
│    faded guides      │   │ ﹁あ﹂│ │ ﹁り﹂│ │…    │            │
│  Follow the light…   │   └─────┘ └─────┘ └─────┘             │
│                      │                                       │
│                      │        [ Show answer ]                │
└──────────────────────┴───────────────────────────────────────┘
```

- **Prompt pane** (~40% width): vertically centred. Mode caption in accent small caps, then
  the mode-specific prompt (docs/02 §2). After reveal it becomes the **ANSWER block**:
  caption "ANSWER" in accent, target text large, pronunciation, English, hint (if any),
  play-audio pill.
- **Canvas pane**: hint line top-left, Undo/Clear pills top-right. Guide boxes centred, sized
  `min(160pt, available/unitCount)`, wrapping to rows of ≤6 boxes for long phrases. Each box:
  hairline border + dashed centre cross (genkō yōshi). Punctuation typeset between boxes,
  no box.
- **Grade row** (after reveal), replacing Show answer:
  `[Again <1m] [Hard 6m] [Good 10m] [Easy 4d]` — interval previews under each label. Again
  tinted red, Easy tinted ink-solid, middle two neutral.
- iPhone / portrait: prompt collapses to a compact header band above the canvas; answer
  reveal presents as a bottom sheet over the canvas with grade buttons.

Interaction details:

- Canvas accepts strokes any time before grading; writing before "Show answer" is expected.
- Pencil double-tap → Undo.
- Audio modes: card entry autoplays (setting), tapping the big play button replays.
- Progress bar animates per grade; the queue chips tick down live.

### 2.4 Session summary

- Centred column: 済 in a red disc, "お疲れさま！", "Session complete — 12 cards written in
  6 min".
- 2×2 grade count grid (Again / Hard / Good / Easy).
- Streak footer: "🔥 5 day streak · keep it going tomorrow".
- Buttons: **Back to decks** (primary), **Study another deck** (quiet).

## 3. Motion

- Card-to-card: quick crossfade + slight horizontal slide of the prompt pane; canvas just
  clears. Keep under 250ms — the loop must feel fast.
- Answer reveal: prompt content crossfades into answer block; grade row springs up.
- Summary: single gentle scale-in of the 済 disc. Nothing else animates.

## 4. Accessibility

- All interactive elements ≥44pt; grade buttons full-height rows on small screens.
- Dynamic Type: everything scales except the answer glyphs and guide boxes (they're the
  content, not chrome); prompt/answer metadata text scales.
- VoiceOver: canvas exposes a custom action "Show answer"; grade buttons read as
  "Again — due in under 1 minute", etc. Written practice is inherently visual; recognition
  modes remain usable and audio buttons are labelled.
- Reduce Motion: disable slide, keep crossfades.

## 5. App icon direction

Vermillion hanko-stamp square, off-white 書 (or the Kakitori mark) inside, on paper
background. Matches the in-app identity; reads at small sizes.
