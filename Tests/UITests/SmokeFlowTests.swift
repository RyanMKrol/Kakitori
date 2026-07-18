import XCTest

/// End-to-end smoke flow: seeded launch → open a deck → start a Trace session → reveal → grade →
/// session advances. Smoke, not coverage — exactly ONE flow. All waits are bounded; every query is
/// by `accessibilityIdentifier` (the UI is bilingual, so display copy is never queried).
final class SmokeFlowTests: XCTestCase {
    @MainActor
    func testSeededLaunchStartTraceSessionRevealGradeAdvances() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedDemoData", "YES"]
        app.launch()

        // A deck row — query by identifier prefix (rows carry deck-row-<name>), not display name.
        let deckRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'deck-row-'"))
            .firstMatch
        XCTAssertTrue(deckRow.waitForExistence(timeout: 15), "A seeded deck row should appear on Home.")
        deckRow.tap()

        // Deck setup sheet → Trace mode → Start writing.
        let traceMode = app.buttons["mode-trace"]
        XCTAssertTrue(traceMode.waitForExistence(timeout: 10), "The deck setup sheet should offer mode-trace.")
        traceMode.tap()

        let startWriting = app.buttons["start-writing"]
        XCTAssertTrue(
            startWriting.waitForExistence(timeout: 10),
            "start-writing should be available once a mode is picked."
        )
        startWriting.tap()

        // In the session: reveal the answer.
        let showAnswer = app.buttons["show-answer"]
        XCTAssertTrue(showAnswer.waitForExistence(timeout: 10), "The session should show the Show answer action.")
        showAnswer.tap()

        // Grade Good.
        let gradeGood = app.buttons["grade-good"]
        XCTAssertTrue(
            gradeGood.waitForExistence(timeout: 10),
            "The grade row should appear after revealing the answer."
        )
        gradeGood.tap()

        // The session advanced: the next card is served in its pre-reveal state, so the grade row is
        // replaced by Show answer again — and grade-good is no longer present.
        XCTAssertTrue(
            showAnswer.waitForExistence(timeout: 10),
            "Show answer should reappear once the next card is served."
        )
        XCTAssertFalse(gradeGood.exists, "grade-good should be gone once the session advanced to the next card.")
    }
}
