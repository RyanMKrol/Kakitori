@testable import Kakitori
import SwiftUI
import XCTest

final class ThemeMotionTests: XCTestCase {
    func testCardTransitionWithReduceMotionDisabled() {
        let transition = KakitoriTheme.cardTransition(reduceMotion: false)
        XCTAssertNotNil(transition)
    }

    func testCardTransitionWithReduceMotionEnabled() {
        let transition = KakitoriTheme.cardTransition(reduceMotion: true)
        XCTAssertNotNil(transition)
    }

    func testEmphasisTransitionWithReduceMotionDisabled() {
        let transition = KakitoriTheme.emphasisTransition(reduceMotion: false)
        XCTAssertNotNil(transition)
    }

    func testEmphasisTransitionWithReduceMotionEnabled() {
        let transition = KakitoriTheme.emphasisTransition(reduceMotion: true)
        XCTAssertNotNil(transition)
    }
}
