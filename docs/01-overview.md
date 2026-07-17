# Kakitori — Overview

## What is Kakitori?

**Kakitori** (書き取り — "writing down / dictation practice") is a native iOS/iPadOS app for
learning to **write** Japanese characters by hand. Where most kana/kanji apps drill
*recognition* (multiple choice, flashcards you only read), Kakitori drills *production*: you
physically write each character on a canvas, card by card, and a spaced-repetition system
schedules what you practice next.

The name is the actual Japanese word for the school exercise of writing out characters from
dictation or memory — which is exactly what the app does.

## The core loop

1. Pick a **deck** (a script or character set: Hiragana, Katakana, starter Kanji).
2. Pick a **practice mode** (Trace, Listen & Write, Translate & Write, Recall).
3. For each due card, **write the character(s) by hand** on the canvas (finger or Apple Pencil).
4. Reveal the **answer** and self-grade: Again / Hard / Good / Easy.
5. The **SRS scheduler** decides when you see that card next.
6. Finish the session, see your summary, keep your **streak** alive.

## Why it exists

- Writing is the weakest skill for most Japanese learners; recognition apps create an illusion
  of knowing a character that falls apart with a blank page and a pen.
- Handwriting builds stroke-order intuition, which in turn improves reading of handwritten and
  stylised text.
- iPad + Apple Pencil is the ideal hardware for this, and no dominant app owns the
  "SRS × handwriting" niche well.

## Product principles

1. **Production over recognition.** Every interaction ends with the user having written
   something by hand.
2. **Honest self-grading.** v1 uses Anki-style self-assessment against a revealed answer, not
   automated stroke recognition. Automated feedback (stroke order/shape scoring) is a future
   enhancement, never a gate.
3. **Calm, paper-like aesthetic.** Off-white canvas, ink strokes, genkō yōshi-style guide
   boxes. No gamification noise beyond streaks and session stats.
4. **Sessions are short and finishable.** A session is a bounded queue of due cards, with a
   clear end state ("お疲れさま！").
5. **Offline-first.** All content and progress lives on device; nothing requires an account or
   network (audio uses on-device speech synthesis in v1).

## v1 scope (summary)

| Area | v1 | Later |
|---|---|---|
| Scripts | Hiragana (incl. dakuten/combos), Katakana (same), starter Kanji (~N5/Grade 1, ~100 chars) | Full Jōyō kanji, vocabulary decks, custom decks |
| Modes | Trace, Listen & Write, Translate & Write, Recall | Stroke-order playback, auto-scoring |
| Scheduling | SM-2-derived SRS with 4 grades | FSRS, per-deck tuning |
| Input | PencilKit canvas, finger + Apple Pencil | Handwriting recognition feedback |
| Audio | AVSpeechSynthesizer (ja-JP) | Recorded native audio |
| Sync | On-device (SwiftData) | iCloud sync |
| Platform | iPadOS + iOS (universal) | macOS (Catalyst/native), widgets |

## Documents in this folder

| Doc | Contents |
|---|---|
| [02-product-spec.md](02-product-spec.md) | Screens, flows, practice modes, feature behaviour |
| [03-srs-algorithm.md](03-srs-algorithm.md) | Card states, scheduling math, session queue rules |
| [04-content-and-data.md](04-content-and-data.md) | Decks, character data, stroke data sources, audio |
| [05-architecture.md](05-architecture.md) | Tech stack, module layout, data model, key components |
| [06-ui-design.md](06-ui-design.md) | Visual language, per-screen layout, interaction details |
| [07-roadmap.md](07-roadmap.md) | Build order, milestones, future ideas |

A working HTML prototype (built before this project) lives in `../reference/` — it is the
visual and behavioural reference for v1.
