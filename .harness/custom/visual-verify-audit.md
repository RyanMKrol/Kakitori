## Project-specific visual verification — audit side (Kakitori)

When auditing a task that made a visual `## Done when` claim, be adversarial about the evidence:

- **No capture = FAIL.** If the change touches the UI (`views` or `canvas` layer) and no
  `screenshots/latest.png` (or a frame from a recorded video, for animated claims) was produced, the
  visual claim is unverified — fail. Do not accept "the build passed" as visual verification; the
  whole point of this check is that tests can pass while the screen looks wrong.
- **Letterbox bars = FAIL.** Black bars top and bottom with scaled-up UI means a missing launch
  screen (legacy compatibility mode). This distorts every screen — fail it before assessing anything
  else.
- **Claim must be evidenced by the actual pixels.** For each visual `## Done when` line (e.g. "guide
  boxes render with dashed cross-lines", "answer block shows target + reading + English", "grade row
  shows interval previews"), the screenshot must actually show it. A truncated, blank, or
  default-blue-tinted screen fails — Kakitori's palette is paper `#FAF8F4` / ink `#1A1A1A` /
  vermillion `#C43B2E`, and Japanese display glyphs are Mincho-serif, not system sans.
- **Canvas claims need the canvas visible.** A claim about strokes, undo/clear, or trace guides is
  only verified by a screenshot showing the guide boxes (and, for trace mode, the faded guide glyph
  UNDER the boxes). An empty Home screenshot does not verify a session-screen claim.
- **Animated/timing claims need a video, not a still.** Card-to-card transitions, the answer-reveal
  crossfade, and the summary 済-disc scale-in are only verified by frames from
  `simctl io … recordVideo`, never one screenshot.
