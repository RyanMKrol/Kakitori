# Kakitori — standing rules for every build (injected into every builder prompt)

- **The `.xcodeproj` is generated — never hand-edit it or `Sources/Info.plist`.** Change project-level
  settings by editing `project.yml` and running `xcodegen generate`. New source files just go under
  `Sources/` (or `Tests/`) and are picked up automatically on the next generate.
- **Test destination — ALWAYS the dedicated `Kakitori-Sim` (an iPad), never a generic model name.**
  Ensure it exists with `./tools/loop_sim.sh` (idempotent; prints the UDID). **This overrides any
  command text quoted in a task's spec or `verify`:** if a spec says `name=iPhone 16` (or any generic
  model), substitute `name=Kakitori-Sim` when you run it. Any NEW script or tool a task has you create
  that boots or targets a simulator must default to `Kakitori-Sim` via `tools/loop_sim.sh`, never a
  generic model. Simulators are exclusive resources — several autonomous iOS loops share this Mac
  (Scout, Sprout, Enough, Basket), and two loops installing/launching onto one device stamp on each
  other. (Exception 1: CI workflows resolve their own runner-local sim — never "fix" CI to
  `Kakitori-Sim`.) (Exception 2: a task whose spec EXPLICITLY verifies the iPhone/compact layout may
  take its screenshot on a generic iPhone via `./build_run.sh "iPhone 16"` — the compact layout
  cannot appear on the iPad — but all tests and the DoD still run on `Kakitori-Sim`.)
- **Determinism — injected clock, injected randomness.** Any "current time" read in scheduler /
  session-queue / streak / daily-stats code comes from an injected clock (`now: Date` parameter or an
  `AppClock`-style provider), never a bare `Date()` / `.now` — the 4 AM day-rollover and interval math
  must be unit-testable against a scripted clock. The SM-2 ±5% interval fuzz uses an injected, seedable
  `RandomNumberGenerator`, never `Double.random(in:)` with the system RNG — fuzz bounds are asserted in
  tests.
- **Tests never touch real state.** Unit tests run against an **in-memory SwiftData
  `ModelContainer`** (never the app's `Application Support/Kakitori/` store); importer tests unzip the
  checked-in fixture `.apkg` into a temp directory and never hit the network. Audio
  (`AVAudioPlayer` / `AVSpeechSynthesizer`) sits behind a protocol (`AudioPlaying`) with a scripted
  fake — tests never do real playback.
- **iOS 18+, Swift 6 strict-concurrency clean, modern APIs only.** `@Observable` (not
  `ObservableObject`), `NavigationStack` (not `NavigationView`). SwiftData access stays on the main
  actor (data volumes are tiny) except the `ApkgImporter`, which is an `actor`.
- **No force-unwraps (`!`) or `try!`** in non-test `Sources`.
- **UI tests follow the house rules:** query by `accessibilityIdentifier` (never display copy — the UI
  is bilingual Japanese/English); use bounded waits (`waitForExistence`), never `sleep()`-polling. Give
  interactive elements stable identifiers as you create them (`deck-row-<name>`, `mode-trace`,
  `show-answer`, `grade-again/hard/good/easy`, `session-close`, `canvas-undo`, `canvas-clear`).
- **Copy style:** user-facing copy specified in `docs/02-product-spec.md` / `docs/06-ui-design.md` and
  the `reference/` prototypes is FINAL — reproduce it character-for-character, including Japanese
  strings (ひらがな, お疲れさま！, 書 / 聞 / 訳 / 思 mode glyphs). Only copy you invent yourself (log
  messages, new strings no spec dictates) avoids em dashes.
- **The design docs are the spec.** `docs/03-srs-algorithm.md` is the exact SM-2 math (steps, ease
  deltas, clamps, caps); `docs/04-content-and-data.md` is the exact `.apkg` field contract. When a task
  spec and a design doc disagree on a constant, flag it in the worklog and follow the task spec.
