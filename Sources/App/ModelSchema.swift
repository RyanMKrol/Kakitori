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

/// `DailyStats` after per-deck `deckKey` but BEFORE the unified daily-progress fields
/// (`dailyTarget` / `completedCardIDs`). Frozen here so V2 keeps its historical shape while the
/// live `DailyStats` (Sources/Models/DailyStats.swift) moves on to V3.
enum KakitoriSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self]
    }

    @Model
    final class DailyStats {
        var day: String
        var cardsWritten: Int
        var newIntroduced: Int
        var reviewsDone: Int
        var secondsStudied: Int
        var deckKey: String?

        init(
            day: String,
            cardsWritten: Int = 0,
            newIntroduced: Int = 0,
            reviewsDone: Int = 0,
            secondsStudied: Int = 0,
            deckKey: String? = nil
        ) {
            self.day = day
            self.cardsWritten = cardsWritten
            self.newIntroduced = newIntroduced
            self.reviewsDone = reviewsDone
            self.secondsStudied = secondsStudied
            self.deckKey = deckKey
        }
    }
}

/// The current schema — `DailyStats` gained the unified daily-progress fields `dailyTarget`
/// (snapshot, default 0) and `completedCardIDs` (default `[]`).
enum KakitoriSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Deck.self, Section.self, Note.self, CardSchedule.self, DailyStats.self]
    }
}

enum KakitoriMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KakitoriSchemaV1.self, KakitoriSchemaV2.self, KakitoriSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// Purely additive (`deckKey` is a new optional property, default `nil`) — a lightweight
    /// migration backfills every existing row as legacy/global (`deckKey == nil`), preserving it.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: KakitoriSchemaV1.self,
        toVersion: KakitoriSchemaV2.self
    )

    /// Purely additive (`dailyTarget` defaults to 0, `completedCardIDs` to `[]`) — lightweight,
    /// preserving every existing row; the target is (re)snapshotted lazily on the next day-start.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: KakitoriSchemaV2.self,
        toVersion: KakitoriSchemaV3.self
    )
}
