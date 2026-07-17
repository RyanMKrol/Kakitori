import Foundation
import SwiftData

@Model
final class Deck {
    var id: UUID
    var name: String
    var jpTitle: String?
    var sourceDeckName: String
    var importedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Section.deck) var sections: [Section] = []

    init(
        id: UUID = UUID(),
        name: String,
        jpTitle: String? = nil,
        sourceDeckName: String,
        importedAt: Date,
        sections: [Section] = []
    ) {
        self.id = id
        self.name = name
        self.jpTitle = jpTitle
        self.sourceDeckName = sourceDeckName
        self.importedAt = importedAt
        self.sections = sections
    }
}

@Model
final class Section {
    var id: UUID
    var name: String
    var orderIndex: Int
    var deck: Deck?

    init(id: UUID = UUID(), name: String, orderIndex: Int) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
    }
}
