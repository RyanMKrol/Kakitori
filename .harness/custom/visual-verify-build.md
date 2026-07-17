## Project-specific visual verification (Kakitori)

- Capture via `./build_run.sh` — it generates, builds, installs, launches on the dedicated
  **Kakitori-Sim iPad** simulator, and writes `screenshots/latest.png`. Look at that file.
- Extra args after the sim name are passed to `simctl launch`, e.g.
  `./build_run.sh Kakitori-Sim -seedDemoData YES` once the demo-seed task has landed — use it to
  verify populated Home/session states instead of the empty first-run screen.
- **Screenshot at DEFAULT text size unless your task is specifically about Dynamic Type.** The
  simulator's Dynamic Type is a PERSISTENT setting, so an accessibility-sizing task can leave it
  cranked up and make every later task's screenshot look wrongly oversized. `build_run.sh` resets it
  (`xcrun simctl ui "$SIM" content_size large` — note the UNDERSCORE), but reset it yourself too if
  you changed it mid-task. Only an explicit accessibility task sets an `accessibility-*` size, and it
  MUST reset to `large` when it finishes.
- **The app MUST fill the whole screen.** Black letterbox bars top/bottom with scaled-up UI in the
  middle = missing launch screen (iOS legacy compatibility mode) — a hard FAIL, not a style nit.
  Confirm `UILaunchScreen` is present in the generated `Sources/Info.plist`
  (`plutil -extract UILaunchScreen xml1 -o - Sources/Info.plist`). Judge this BEFORE any component.
- Judge against `docs/06-ui-design.md` and the `reference/` prototype screenshots:
  - **Palette:** paper `#FAF8F4` background, ink `#1A1A1A` text, vermillion accent `#C43B2E`
    (hanko red) on mode labels / ANSWER caption / primary buttons / streak. A default-blue SwiftUI
    tint anywhere = NOT verified.
  - **Japanese display glyphs** (answers, trace guides) render in Hiragino Mincho ProN — a
    system-sans Japanese glyph in the answer block or guide boxes is wrong.
  - **Guide boxes** are genkō yōshi style: square, hairline `8% ink` border, dashed center
    cross-lines; ≤6 per row on iPad, punctuation (。、！？) rendered in-line WITHOUT a box.
  - **iPad session layout** is side-by-side: prompt pane (~40%) left, canvas right, action row
    below the canvas. Truncated text, missing sections, or a blank screen = NOT verified.
- Record in the worklog which screens you captured and what you observed.

### Navigating to your screen (xcui/xclog — only if the Axiom plugin is installed)

If `ls ~/.claude/plugins/cache/axiom-marketplace/axiom/*/bin/xcui` matches (skip this whole
section otherwise), you can DRIVE the simulator to the screen you changed instead of judging only
the launch screen. The UI carries stable accessibility identifiers (see the build preamble's
identifier list).

```bash
XCUI=$(ls ~/.claude/plugins/cache/axiom-marketplace/axiom/*/bin/xcui 2>/dev/null | tail -1)
UDID=$(./tools/loop_sim.sh)                                     # the dedicated Kakitori-Sim
"$XCUI" wait --for-element deck-row-hiragana --timeout 10s --udid "$UDID"
"$XCUI" assert --id show-answer --trait button --udid "$UDID"   # semantic assert (exit 1 = fail)
xcrun simctl io "$UDID" screenshot screenshots/latest.png       # re-screenshot on that screen
```

Prefer one `xcui assert` on the element your task changed — it checks label text the screenshot
can't. Blank screenshot? Capture the console first:
`xclog launch com.ryankrol.kakitori --timeout 30s --max-lines 200 --device "$UDID"`
(note: xclog terminates and relaunches the app).
