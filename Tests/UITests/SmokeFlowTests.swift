import XCTest

/// End-to-end smoke flow: seeded launch → open a deck → start a Trace session → reveal → grade →
/// session advances. Smoke, not coverage — exactly ONE flow. All waits are bounded; every query is
/// by `accessibilityIdentifier` (the UI is bilingual, so display copy is never queried).
final class SmokeFlowTests: XCTestCase {
    @MainActor
    func testLaunchStartTraceSessionRevealGradeAdvances() {
        let app = XCUIApplication()
        app.launch()

        // Deck rows — query by identifier prefix (rows carry deck-row-<name>), not display name.
        // The bundled decks import on first launch, so allow generous time for that one-time load.
        let deckRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'deck-row-'"))
        XCTAssertTrue(
            deckRows.firstMatch.waitForExistence(timeout: 60),
            "A bundled deck row should appear on Home once loaded."
        )

        // Don't assume the FIRST deck has cards due. A deck that has finished its daily target
        // offers Free Study instead of "Start writing", and this test needs a normal SRS session.
        // A fresh simulator hits that on deck 0, but a device that has already been studied today
        // does not — and the local Definition-of-Done gate runs on exactly such a device, so
        // assuming deck 0 makes the whole gate fail as the day progresses.
        let startWriting = app.buttons["start-writing"]
        let closeSheet = app.buttons["deck-setup-close"]
        var startedSession = false

        for index in 0 ..< deckRows.count {
            deckRows.element(boundBy: index).tap()

            let traceMode = app.buttons["mode-trace"]
            XCTAssertTrue(traceMode.waitForExistence(timeout: 10), "The deck setup sheet should offer mode-trace.")
            traceMode.tap()

            if startWriting.waitForExistence(timeout: 3) {
                startWriting.tap()
                startedSession = true
                break
            }

            // Caught up — close and try the next deck.
            closeSheet.tap()
            XCTAssertTrue(closeSheet.waitForNonExistence(timeout: 5), "The deck setup sheet should dismiss.")
        }

        XCTAssertTrue(startedSession, "No deck had cards due — every bundled deck is already done for today.")

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
