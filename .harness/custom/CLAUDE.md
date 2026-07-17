# .harness/custom/CLAUDE.md — your project-specific harness instructions

This is the **customization overlay** for `.harness/CLAUDE.md`. Anything you add here loads automatically
(the pristine `.harness/CLAUDE.md` imports it with `@custom/CLAUDE.md`), and **harness upgrades never touch
this file** — so this is where your edits belong.

## Why this file exists — the overlay rule

The harness's own prose files (`.harness/CLAUDE.md`, `README.md`, and everything under `docs/`) are
**plugin-owned**: `implementation-harness:upgrade` refreshes them from the latest plugin version. If you
edit them in place, your changes collide with every future upgrade and force a manual reconcile. Instead,
put project-specific additions in the matching file under `.harness/custom/` — this tree **mirrors** the
harness layout (`custom/CLAUDE.md`, `custom/README.md`, `custom/docs/HARNESS.md`, …). The pristine files
then stay byte-identical to the plugin and upgrade cleanly, while your customizations ride along untouched.

(Scripts and config are NOT covered by this prose overlay — customize the loop via `config/harness.env`,
and if you need a script change, flag it to upstream into the plugin rather than hand-editing in place.)

Add your project's harness-authoring conventions, house rules, and reminders below.

## Kakitori authoring conventions

- **Size tasks for a Haiku-class builder.** One type / one screen region / one behavior per task,
  buildable in one cold pass from the spec alone. A task spec should quote the exact constants,
  field names, and copy strings it needs from `docs/` rather than saying "see the docs" — the
  builder should not have to synthesize across documents.
- **Point specs at their source-of-truth doc section** (e.g. "docs/03-srs-algorithm.md §4 Grade
  transitions") so an auditor can check fidelity, but inline the load-bearing values into the spec.
- **Layer picks:** `canvas` is for PencilKit/guide-box/trace-layer work (even though it lives under
  `Sources/Features/Session/Canvas/`); plain SwiftUI screens are `views`; `Scheduler/` and
  `SessionQueue` logic is `scheduler`; `.apkg`/SQLite/segmentation is `importer`; `@Model` types,
  stats, streak, settings storage are `data`; audio + clock providers are `services`.
- **Anything needing real Apple Pencil feel** (ink-tuning, brush width judgment) is a
  `needs-human` gate — a simulator screenshot cannot verify it (docs/07-roadmap.md M1 risk gate).
- **New-card rule reminders that trip up naive specs:** new cards always appear in **Trace** first
  regardless of session mode; scheduling state is **per card, not per mode**; sub-day cards
  **re-enter the live session queue**; the day rolls over at **4 AM local** (Anki convention).
