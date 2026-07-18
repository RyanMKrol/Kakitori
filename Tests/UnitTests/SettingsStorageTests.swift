@testable import Kakitori
import XCTest

final class SettingsStorageTests: XCTestCase {
    var testDefaults: UserDefaults!
    var suiteName: String = ""

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStorageTests-" + UUID().uuidString
        testDefaults = UserDefaults(suiteName: suiteName)
        UserDefaults().removePersistentDomain(forName: suiteName)
        testDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        testDefaults = nil
        super.tearDown()
    }

    func testFreshSuiteReadsDefaults() {
        let settings = AppSettings(defaults: testDefaults)

        XCTAssertEqual(settings.newCardsPerDay, 10)
        XCTAssertEqual(settings.maxReviewsPerDay, 100)
        XCTAssertTrue(settings.audioAutoplay)
        XCTAssertTrue(settings.showRomaji)
    }

    func testRoundTripValues() {
        var settings = AppSettings(defaults: testDefaults)

        settings.newCardsPerDay = 25
        settings.maxReviewsPerDay = 250
        settings.audioAutoplay = false
        settings.showRomaji = false

        let settings2 = AppSettings(defaults: testDefaults)

        XCTAssertEqual(settings2.newCardsPerDay, 25)
        XCTAssertEqual(settings2.maxReviewsPerDay, 250)
        XCTAssertFalse(settings2.audioAutoplay)
        XCTAssertFalse(settings2.showRomaji)
    }
}
