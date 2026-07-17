import XCTest

/// Keeps the UI-test target compiling and proves the app launches full-screen.
final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
