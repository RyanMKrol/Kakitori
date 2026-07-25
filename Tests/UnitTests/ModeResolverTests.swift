@testable import Kakitori
import XCTest

final class ModeResolverTests: XCTestCase {
    func testMixedRotatesThreeModes() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [.trace, .listen, .translate])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let modes = [
            resolver.nextMode(qualifies: qualifyAll),
            resolver.nextMode(qualifies: qualifyAll),
            resolver.nextMode(qualifies: qualifyAll),
            resolver.nextMode(qualifies: qualifyAll),
            resolver.nextMode(qualifies: qualifyAll),
        ]

        XCTAssertEqual(modes, [.trace, .listen, .translate, .trace, .listen])
    }

    func testMixedSkipsUnqualifiedMode() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [.trace, .listen, .translate])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let mode1 = resolver.nextMode(qualifies: qualifyAll)
        XCTAssertEqual(mode1, .trace)

        let skipListen: (PracticeMode) -> Bool = { mode in
            mode != .listen
        }
        let mode2 = resolver.nextMode(qualifies: skipListen)
        XCTAssertEqual(mode2, .translate)

        // After translate the rotation wraps back to trace.
        let mode3 = resolver.nextMode(qualifies: qualifyAll)
        XCTAssertEqual(mode3, .trace)
    }

    /// The chosen mode is honoured on every card, including a card's very first exposure. An
    /// earlier build forced first exposures into Trace; that override is gone.
    func testChosenModeIsHonouredOnEveryCard() {
        var resolver = ModeResolver(sessionMode: .listen, availableModes: [])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        XCTAssertEqual(resolver.nextMode(qualifies: qualifyAll), .listen)
        XCTAssertEqual(resolver.nextMode(qualifies: qualifyAll), .listen)
    }

    /// Mixed rotates from the very first card — no card is skipped over or pinned to Trace.
    func testMixedRotatesFromTheFirstCard() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [.trace, .listen, .translate])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        XCTAssertEqual(resolver.nextMode(qualifies: qualifyAll), .trace)
        XCTAssertEqual(resolver.nextMode(qualifies: qualifyAll), .listen)
        XCTAssertEqual(resolver.nextMode(qualifies: qualifyAll), .translate)
    }

    func testNonMixedModeIgnoresAvailableModes() {
        var resolver = ModeResolver(sessionMode: .translate, availableModes: [.trace, .listen])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let mode = resolver.nextMode(qualifies: qualifyAll)
        XCTAssertEqual(mode, .translate)
    }

    func testNonMixedModeFallsBackToTraceWhenNotQualified() {
        var resolver = ModeResolver(sessionMode: .listen, availableModes: [])
        let qualifyNone: (PracticeMode) -> Bool = { _ in false }

        let mode = resolver.nextMode(qualifies: qualifyNone)
        XCTAssertEqual(mode, .trace)
    }

    func testEmptyAvailableModesReturnTrace() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let mode = resolver.nextMode(qualifies: qualifyAll)
        XCTAssertEqual(mode, .trace)
    }

    func testMixedNoQualifiedModeReturnsTrace() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [.trace, .listen, .translate])
        let qualifyNone: (PracticeMode) -> Bool = { _ in false }

        let mode = resolver.nextMode(qualifies: qualifyNone)
        XCTAssertEqual(mode, .trace)
    }
}
