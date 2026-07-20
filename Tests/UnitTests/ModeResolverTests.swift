@testable import Kakitori
import XCTest

final class ModeResolverTests: XCTestCase {
    func testMixedRotatesThreeModes() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [.trace, .listen, .translate])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let modes = [
            resolver.nextMode(cardState: .learning, qualifies: qualifyAll),
            resolver.nextMode(cardState: .learning, qualifies: qualifyAll),
            resolver.nextMode(cardState: .learning, qualifies: qualifyAll),
            resolver.nextMode(cardState: .learning, qualifies: qualifyAll),
            resolver.nextMode(cardState: .learning, qualifies: qualifyAll),
        ]

        XCTAssertEqual(modes, [.trace, .listen, .translate, .trace, .listen])
    }

    func testMixedSkipsUnqualifiedMode() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [.trace, .listen, .translate])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let mode1 = resolver.nextMode(cardState: .learning, qualifies: qualifyAll)
        XCTAssertEqual(mode1, .trace)

        let skipListen: (PracticeMode) -> Bool = { mode in
            mode != .listen
        }
        let mode2 = resolver.nextMode(cardState: .learning, qualifies: skipListen)
        XCTAssertEqual(mode2, .translate)

        // After translate the rotation wraps back to trace.
        let mode3 = resolver.nextMode(cardState: .learning, qualifies: qualifyAll)
        XCTAssertEqual(mode3, .trace)
    }

    func testNewCardForcedToTrace() {
        var resolver = ModeResolver(sessionMode: .listen, availableModes: [])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let mode1 = resolver.nextMode(cardState: .new, qualifies: qualifyAll)
        XCTAssertEqual(mode1, .trace)

        let mode2 = resolver.nextMode(cardState: .learning, qualifies: qualifyAll)
        XCTAssertEqual(mode2, .listen)
    }

    func testNewCardDoesNotConsumeRotationStep() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [.trace, .listen, .translate])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let mode1 = resolver.nextMode(cardState: .new, qualifies: qualifyAll)
        XCTAssertEqual(mode1, .trace)

        let mode2 = resolver.nextMode(cardState: .learning, qualifies: qualifyAll)
        XCTAssertEqual(mode2, .trace)
    }

    func testNonMixedModeIgnoresAvailableModes() {
        var resolver = ModeResolver(sessionMode: .translate, availableModes: [.trace, .listen])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let mode = resolver.nextMode(cardState: .learning, qualifies: qualifyAll)
        XCTAssertEqual(mode, .translate)
    }

    func testNonMixedModeFallsBackToTraceWhenNotQualified() {
        var resolver = ModeResolver(sessionMode: .listen, availableModes: [])
        let qualifyNone: (PracticeMode) -> Bool = { _ in false }

        let mode = resolver.nextMode(cardState: .learning, qualifies: qualifyNone)
        XCTAssertEqual(mode, .trace)
    }

    func testEmptyAvailableModesReturnTrace() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [])
        let qualifyAll: (PracticeMode) -> Bool = { _ in true }

        let mode = resolver.nextMode(cardState: .learning, qualifies: qualifyAll)
        XCTAssertEqual(mode, .trace)
    }

    func testMixedNoQualifiedModeReturnsTrace() {
        var resolver = ModeResolver(sessionMode: .mixed, availableModes: [.trace, .listen, .translate])
        let qualifyNone: (PracticeMode) -> Bool = { _ in false }

        let mode = resolver.nextMode(cardState: .learning, qualifies: qualifyNone)
        XCTAssertEqual(mode, .trace)
    }
}
