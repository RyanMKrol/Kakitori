import Foundation
import SwiftData

/// Versioned schema history for the on-device store. `DailyStats` gained `deckKey` (per-deck
/// daily progress/caps, replacing the old whole-app-global row) — this pair lets SwiftData
/// migrate an existing install instead of crashing on open (see `KakitoriApp.makeModelContainer`).
enum KakitoriSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self]
    }

    /// `DailyStats` as it existed before per-deck daily progress — no `deckKey`.
    @Model
    final class DailyStats {
        var day: String
        var cardsWritten: Int
        var newIntroduced: Int
        var reviewsDone: Int
        var secondsStudied: Int

        init(
            day: String,
            cardsWritten: Int = 0,
            newIntroduced: Int = 0,
            reviewsDone: Int = 0,
            secondsStudied: Int = 0
        ) {
            self.day = day
            self.cardsWritten = cardsWritten
            self.newIntroduced = newIntroduced
            self.reviewsDone = reviewsDone
            self.secondsStudied = secondsStudied
        }
    }
}

/// The current schema — `DailyStats` (Sources/Models/DailyStats.swift) plus the unchanged models.
enum KakitoriSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self]
    }
}

enum KakitoriMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KakitoriSchemaV1.self, KakitoriSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Purely additive (`deckKey` is a new optional property, default `nil`) — a lightweight
    /// migration backfills every existing row as legacy/global (`deckKey == nil`), preserving it.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: KakitoriSchemaV1.self,
        toVersion: KakitoriSchemaV2.self
    )
}
