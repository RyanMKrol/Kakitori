# Kakitori — standing rules for every audit (injected into every auditor prompt)

Beyond the task's `## Done when`, FAIL the audit if the diff violates any of these repo invariants:

- **Generated files hand-edited:** any change to `Kakitori.xcodeproj/**` or `Sources/Info.plist`
  without a corresponding `project.yml` change is a hand-edit of XcodeGen output — fail.
- **Determinism leaks:** new scheduler / session-queue / streak / daily-stats code reading bare
  `.now` / `Date()` instead of an injected clock, or SM-2 interval fuzz using the system RNG instead
  of an injected seedable `RandomNumberGenerator` — fail (day-rollover and interval math can't be
  unit-tested deterministically).
- **Tests touching real state:** a test using the app's real SwiftData store (anything other than an
  in-memory `ModelContainer`), writing outside a temp directory, doing real audio playback, or hitting
  the network — fail.
- **Legacy APIs:** `ObservableObject` / `NavigationView` introduced where the iOS 18+ modern
  equivalent applies (`@Observable` / `NavigationStack`) — fail.
- **Force-unwraps:** a new `!` force-unwrap or `try!` in non-test `Sources` — fail.
- **UI-test house-rule violations:** new XCUITest querying by display copy instead of
  `accessibilityIdentifier` (the UI is bilingual — copy-queries are doubly fragile), or `sleep()`
  polling instead of bounded waits — fail.
- **Copy fidelity:** a Japanese or English user-facing string that `docs/02-product-spec.md` /
  `docs/06-ui-design.md` specifies, reproduced inexactly — fail. An em dash introduced in
  *invented* user-facing copy (strings no spec dictates) — fail.
- **SRS math drift:** a scheduling constant (learning steps, ease deltas, interval multipliers,
  clamps, caps, 4 AM rollover) that differs from `docs/03-srs-algorithm.md` without the task spec
  explicitly calling for it — fail.
- **Simulator pinning regressions:** a NEW local script/command targeting a generic simulator model
  name instead of `Kakitori-Sim` (CI workflows excepted) — fail.
