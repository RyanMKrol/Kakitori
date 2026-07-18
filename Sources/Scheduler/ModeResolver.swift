import Foundation

struct ModeResolver {
    private let sessionMode: PracticeMode
    private let availableModes: [PracticeMode]
    private var rotationIndex: Int = 0

    init(sessionMode: PracticeMode, availableModes: [PracticeMode]) {
        self.sessionMode = sessionMode
        self.availableModes = availableModes
    }

    mutating func nextMode(cardState: CardState, qualifies: (PracticeMode) -> Bool) -> PracticeMode {
        if cardState == .new {
            return .trace
        }

        if sessionMode != .mixed {
            if qualifies(sessionMode) {
                return sessionMode
            } else {
                return .trace
            }
        }

        if availableModes.isEmpty {
            return .trace
        }

        for i in 0 ..< availableModes.count {
            let index = (rotationIndex + i) % availableModes.count
            let mode = availableModes[index]
            if qualifies(mode) {
                rotationIndex = (index + 1) % availableModes.count
                return mode
            }
        }

        return .trace
    }
}
