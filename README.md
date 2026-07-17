# Kakitori (書き取り)

A native iOS/iPadOS app for learning to **write** Japanese by hand — kana and kanji practiced
card by card on a PencilKit canvas, scheduled by spaced repetition, fed by Anki `.apkg` decks
produced by the companion [anki-builder](../anki-builder) pipeline.

> 書き取り *kakitori* — the school exercise of writing characters from dictation or memory.

## Status

📐 **Design phase.** Documentation is complete; implementation has not started.

## Building this project

This project is built by an autonomous implementation harness. To add work and run it, see
[`.harness/README.md`](.harness/README.md).

## Documentation

| Doc | Contents |
|---|---|
| [docs/01-overview.md](docs/01-overview.md) | Vision, principles, v1 scope |
| [docs/02-product-spec.md](docs/02-product-spec.md) | Screens, flows, practice modes |
| [docs/03-srs-algorithm.md](docs/03-srs-algorithm.md) | Scheduling design (SM-2 derived) |
| [docs/04-content-and-data.md](docs/04-content-and-data.md) | `.apkg` import contract, media, storage |
| [docs/05-architecture.md](docs/05-architecture.md) | Stack, modules, data model, testing |
| [docs/06-ui-design.md](docs/06-ui-design.md) | Visual language, per-screen specs |
| [docs/07-roadmap.md](docs/07-roadmap.md) | Milestones M0–M5, future ideas |

## Reference

`reference/` contains the original HTML prototypes ("Kaki") — iPad and iPhone layouts — and
screenshots. These are the visual and behavioural reference for v1.

## Content

Decks come from `~/Development/anki-builder`. Current source deck:
`anki-builder/output/epubs/japanese-for-busy-people-book-1-kana/deck-v5.apkg` (114 notes,
recorded audio). A kanji deck in the same format is planned.
