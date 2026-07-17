# Kakitori — SRS & Scheduling

Kakitori uses a simplified SM-2-derived scheduler, close to Anki's defaults, with four grades
(Again / Hard / Good / Easy). Imported `.apkg` decks contribute **notes only** — Kakitori
always schedules with its own state and ignores any Anki scheduling data (`cards`, `revlog`)
in the file.

## 1. Card states

Every card is in exactly one state:

```
new ──▶ learning ──▶ review
              ▲          │
              └─ relearn ◀┘  (on Again)
```

- **new** — never studied.
- **learning** — inside the learning steps (short intra-day intervals).
- **review** — graduated; scheduled in days.
- **relearning** — a lapsed review card working back through a short step.

## 2. Per-card scheduling fields

| Field | Meaning | Initial |
|---|---|---|
| `state` | new / learning / review / relearning | new |
| `stepIndex` | position within learning steps | 0 |
| `easeFactor` | multiplier for interval growth | 2.5 |
| `intervalDays` | current review interval | 0 |
| `dueAt` | next due timestamp | — |
| `lapses` | count of Again presses from review state | 0 |

## 3. Parameters (constants in v1, settings later)

| Parameter | Value |
|---|---|
| Learning steps | 1 min, 10 min |
| Graduating interval (Good on last step) | 1 day |
| Easy graduating interval | 4 days |
| Relearning step | 10 min |
| Minimum ease | 1.3 |
| Hard interval multiplier | 1.2 |
| Easy bonus | 1.3 |
| Maximum interval | 365 days |
| New cards/day per deck | 10 (setting) |
| Max reviews/day per deck | 100 (setting) |

## 4. Grade transitions

### Learning / relearning cards

- **Again** → back to step 0; due in step[0] (1 min).
- **Hard** → repeat current step; due in step[current] (no advance).
- **Good** → advance a step; if past the last step, **graduate**: state = review,
  `intervalDays = 1`, ease unchanged.
- **Easy** → graduate immediately: state = review, `intervalDays = 4`.

### Review cards

Let `I` = current interval, `EF` = ease factor.

- **Again** → `lapses += 1`, `EF = max(1.3, EF − 0.20)`, state = relearning (10 min step);
  on re-graduation the new interval is `max(1, round(I × 0.5))`.
- **Hard** → `EF = max(1.3, EF − 0.15)`, `I = round(I × 1.2)`.
- **Good** → `I = round(I × EF)`.
- **Easy** → `EF = EF + 0.15`, `I = round(I × EF × 1.3)`.

All review intervals are clamped to `[1, 365]` days. `dueAt = now + I days` (fuzz of ±5% on
intervals ≥ 3 days, to avoid cards clumping onto the same future day).

The interval each grade would produce is computed *before* the user grades, so the buttons
can preview it ("Good 10m", "Easy 4d") exactly like the prototype.

## 5. Session queue

When a session starts for a deck:

1. Collect **due learning/relearning** cards (due ≤ now).
2. Collect **due review** cards (dueAt ≤ end of today), capped by max reviews/day minus
   reviews already done today.
3. Collect **new** cards, capped by new/day minus new cards already introduced today.
4. Queue order: learning (by dueAt) → interleave review and new (reviews weighted first).

During the session:

- A card graded into a sub-day interval (Again/Hard in learning, Again on review) **re-enters
  the same session queue** when its due time arrives; if the queue would otherwise be empty,
  it is served early. A session therefore ends only when every queued card has reached ≥1-day
  scheduling.
- The header counts (`new / learn / due`) reflect the live queue.

## 6. Modes and scheduling

**Scheduling state is per card, not per mode.** A card graded in any mode updates the single
shared schedule. Mode choice is a session-level lens:

- New cards default to appearing in **Trace** regardless of the chosen mode for their first
  exposure (a card you've never seen shouldn't be a memory test). After first grading, the
  card follows the session's chosen mode.
- This keeps the model simple; per-mode scheduling (separate card per mode, like Anki's
  Recognition/Production templates) is a possible future change — see §8.

## 7. Day boundaries & stats

- The "day" rolls over at **4:00 AM local time** (Anki convention) so late-night sessions
  don't split across days.
- Daily counters (`newIntroduced`, `reviewsDone`, `cardsWritten`, `secondsStudied`) key off
  this adjusted day.
- Streak: consecutive adjusted-days with ≥1 grade. Today shows as continuing the streak even
  before any study; the streak only breaks once a full day passes with no activity.

## 8. Future: per-mode cards and FSRS

Two known evolutions, deliberately out of v1:

- **Per-mode scheduling.** The source Anki decks already define Recognition + Production
  templates per note. Kakitori could similarly make (note × mode) the scheduled unit so
  Recall strength is tracked independently of Trace. Migration: card state copies to all
  mode-cards on upgrade.
- **FSRS.** Anki's modern scheduler yields better intervals from the same 4 grades. The
  scheduler is isolated behind a protocol (see architecture doc) so it can be swapped without
  touching UI or models.
