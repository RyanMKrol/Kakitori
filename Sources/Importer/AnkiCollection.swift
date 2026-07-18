import Foundation
import SQLite3

struct AnkiModel {
    let id: Int64
    let name: String
    let fieldNames: [String]
}

struct AnkiDeckInfo {
    let id: Int64
    let name: String
}

struct AnkiNote {
    let id: Int64
    let guid: String
    let modelID: Int64
    let fields: [String]
    let tags: String
    let deckID: Int64?
}

enum AnkiCollectionError: Error, Equatable {
    case cannotOpen
    case malformedCollection
    case noAnkiBuilderModel
    case zeroNotes
}

struct AnkiCollection {
    let models: [AnkiModel]
    let decks: [AnkiDeckInfo]
    let notes: [AnkiNote]

    init(databaseURL: URL) throws {
        var db: OpaquePointer?
        let path = databaseURL.path

        let rc = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK else {
            sqlite3_close(db)
            throw AnkiCollectionError.cannotOpen
        }

        defer {
            sqlite3_close(db)
        }

        (models, decks) = try AnkiCollection.readModelsAndDecks(from: db)
        let noteCardMapping = try AnkiCollection.readNoteCardMapping(from: db)
        let rawNotes = try AnkiCollection.readNotes(from: db, models: models)

        guard !rawNotes.isEmpty else {
            throw AnkiCollectionError.zeroNotes
        }

        guard models.contains(where: { NoteFieldMapper.hasMappableTarget($0.fieldNames) }) else {
            throw AnkiCollectionError.noAnkiBuilderModel
        }

        notes = rawNotes.map { note in
            AnkiNote(
                id: note.id,
                guid: note.guid,
                modelID: note.modelID,
                fields: note.fields,
                tags: note.tags,
                deckID: noteCardMapping[note.id]
            )
        }
    }

    private static func readModelsAndDecks(from db: OpaquePointer?) throws -> ([AnkiModel], [AnkiDeckInfo]) {
        var statement: OpaquePointer?
        let query = "SELECT models, decks FROM col"

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw AnkiCollectionError.malformedCollection
        }

        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw AnkiCollectionError.malformedCollection
        }

        guard let modelsPtr = sqlite3_column_text(statement, 0),
              let decksPtr = sqlite3_column_text(statement, 1) else {
            throw AnkiCollectionError.malformedCollection
        }

        let modelsData = Data(bytes: modelsPtr, count: Int(sqlite3_column_bytes(statement, 0)))
        let decksData = Data(bytes: decksPtr, count: Int(sqlite3_column_bytes(statement, 1)))

        guard let modelsJSON = try JSONSerialization.jsonObject(with: modelsData) as? [String: Any],
              let decksJSON = try JSONSerialization.jsonObject(with: decksData) as? [String: Any] else {
            throw AnkiCollectionError.malformedCollection
        }

        let models = try parseModels(from: modelsJSON)
        let decks = try parseDecks(from: decksJSON)

        return (models, decks)
    }

    private static func parseModels(from json: [String: Any]) throws -> [AnkiModel] {
        var models: [AnkiModel] = []

        for (idStr, value) in json {
            guard let modelID = Int64(idStr),
                  let modelDict = value as? [String: Any],
                  let name = modelDict["name"] as? String,
                  let fldsArray = modelDict["flds"] as? [[String: Any]] else {
                throw AnkiCollectionError.malformedCollection
            }

            var fieldsByOrd: [(ord: Int, name: String)] = []
            for fieldDict in fldsArray {
                guard let fieldName = fieldDict["name"] as? String,
                      let ord = fieldDict["ord"] as? Int else {
                    throw AnkiCollectionError.malformedCollection
                }
                fieldsByOrd.append((ord: ord, name: fieldName))
            }

            fieldsByOrd.sort { $0.ord < $1.ord }
            let fieldNames = fieldsByOrd.map(\.name)

            models.append(AnkiModel(id: modelID, name: name, fieldNames: fieldNames))
        }

        return models
    }

    private static func parseDecks(from json: [String: Any]) throws -> [AnkiDeckInfo] {
        var decks: [AnkiDeckInfo] = []

        for (idStr, value) in json {
            guard let deckID = Int64(idStr),
                  let deckDict = value as? [String: Any],
                  let name = deckDict["name"] as? String else {
                throw AnkiCollectionError.malformedCollection
            }

            decks.append(AnkiDeckInfo(id: deckID, name: name))
        }

        return decks
    }

    private static func readNotes(from db: OpaquePointer?, models: [AnkiModel]) throws -> [AnkiNote] {
        var statement: OpaquePointer?
        let query = "SELECT id, guid, mid, flds, tags FROM notes"

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw AnkiCollectionError.malformedCollection
        }

        defer {
            sqlite3_finalize(statement)
        }

        var notes: [AnkiNote] = []
        let modelLookup = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let guidPtr = sqlite3_column_text(statement, 1),
                  let fldsPtr = sqlite3_column_text(statement, 3),
                  let tagsPtr = sqlite3_column_text(statement, 4) else {
                throw AnkiCollectionError.malformedCollection
            }

            let id = sqlite3_column_int64(statement, 0)
            let modelID = sqlite3_column_int64(statement, 2)

            let guid = String(cString: guidPtr)
            let fldsStr = String(cString: fldsPtr)
            let tags = String(cString: tagsPtr)

            guard modelLookup[modelID] != nil else {
                throw AnkiCollectionError.malformedCollection
            }

            let fields = fldsStr.components(separatedBy: "\u{1F}")

            notes.append(AnkiNote(
                id: id,
                guid: guid,
                modelID: modelID,
                fields: fields,
                tags: tags,
                deckID: nil
            ))
        }

        return notes
    }

    private static func readNoteCardMapping(from db: OpaquePointer?) throws -> [Int64: Int64] {
        var statement: OpaquePointer?
        let query = "SELECT nid, did FROM cards"

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw AnkiCollectionError.malformedCollection
        }

        defer {
            sqlite3_finalize(statement)
        }

        var mapping: [Int64: Int64] = [:]

        while sqlite3_step(statement) == SQLITE_ROW {
            let noteID = sqlite3_column_int64(statement, 0)
            let deckID = sqlite3_column_int64(statement, 1)

            if mapping[noteID] == nil {
                mapping[noteID] = deckID
            }
        }

        return mapping
    }
}
