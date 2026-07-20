import Foundation
import SwiftData

enum CardState: String, Codable {
    case new
    case learning
    case review
    case relearning
}

@Model
final class CardSchedule {
    var state: CardState
    var stepIndex: Int
    var easeFactor: Double
    var intervalDays: Double
    var dueAt: Date?
    var lapses: Int
    var note: Note?

    init(
        state: CardState = .new,
        stepIndex: Int = 0,
        easeFactor: Double = 2.5,
        intervalDays: Double = 0,
        dueAt: Date? = nil,
        lapses: Int = 0,
        note: Note? = nil
    ) {
        self.state = state
        self.stepIndex = stepIndex
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.dueAt = dueAt
        self.lapses = lapses
        self.note = note
    }
}
