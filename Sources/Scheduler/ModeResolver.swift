import Foundation

/// Resolves the mode a single card is presented in.
///
/// The mode the user picked on the deck setup sheet is honoured on EVERY card, whatever the card's
/// scheduling state. (Earlier builds forced a card's first exposure into Trace; that override is
/// gone — a picked mode is a picked mode.) The only reason a card is presented in something other
/// than the chosen mode is that the card can't support it — no audio for Listen, no English gloss
/// for Translate — in which case it falls back to Trace, which every card supports.
struct ModeResolver {
    private let sessionMode: PracticeMode
    private let availableModes: [PracticeMode]
    private var rotationIndex: Int = 0

    init(sessionMode: PracticeMode, availableModes: [PracticeMode]) {
        self.sessionMode = sessionMode
        self.availableModes = availableModes
    }

    mutating func nextMode(qualifies: (PracticeMode) -> Bool) -> PracticeMode {
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
