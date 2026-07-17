import Foundation
import SwiftData

enum ImporterError: Error, Equatable {
    case badZip
    case noAnkiBuilderModel
    case zeroNotes
}

struct ImportedNote {
    let ankiGUID: String
    let target: String
    let pronunciation: String?
    let english: String?
    let category: String?
    let hint: String?
    let audioFilename: String?
    let sectionName: String?
    let units: [String]
    let script: Script
}

struct ParsedDeck {
    let deckName: String
    let notes: [ImportedNote]
}

actor ApkgImporter {
    private let mediaBaseURL: URL
    private let context: ModelContext

    init(container: ModelContainer, mediaBaseURL: URL) {
        self.mediaBaseURL = mediaBaseURL
        context = ModelContext(container)
    }

    func importDeck(from url: URL) async throws {
        let parsed = try parse(url: url)
        _ = try apply(parsed)
    }

    func parse(url: URL) throws -> ParsedDeck {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try extract(url, to: tempDir)
        let collection = try openCollection(at: tempDir.appendingPathComponent("collection.anki2"))

        guard let targetModel = collection.models.first(where: { $0.fieldNames.contains("Target") }) else {
            throw ImporterError.noAnkiBuilderModel
        }

        let topDeckFullName = topDeckFullName(in: collection)
        let deckName = topDeckFullName.components(separatedBy: "::").first ?? topDeckFullName
        let deckLookup = Dictionary(uniqueKeysWithValues: collection.decks.map { ($0.id, $0.name) })

        let importedNotes = collection.notes
            .filter { $0.modelID == targetModel.id }
            .compactMap { note in
                importedNote(from: note, model: targetModel, deckLookup: deckLookup, topDeckFullName: topDeckFullName)
            }

        return ParsedDeck(deckName: deckName, notes: importedNotes)
    }

    private func extract(_ url: URL, to tempDir: URL) throws {
        let archive: ZipArchive
        do {
            archive = try ZipArchive(url: url)
        } catch {
            throw ImporterError.badZip
        }

        do {
            try archive.extractAll(to: tempDir)
        } catch {
            throw ImporterError.badZip
        }
    }

    private func openCollection(at dbURL: URL) throws -> AnkiCollection {
        do {
            return try AnkiCollection(databaseURL: dbURL)
        } catch AnkiCollectionError.noAnkiBuilderModel {
            throw ImporterError.noAnkiBuilderModel
        } catch AnkiCollectionError.zeroNotes {
            throw ImporterError.zeroNotes
        }
    }

    private func topDeckFullName(in collection: AnkiCollection) -> String {
        var noteCountByDeck: [Int64: Int] = [:]
        for note in collection.notes {
            guard let deckID = note.deckID else { continue }
            noteCountByDeck[deckID, default: 0] += 1
        }

        let topDeck = collection.decks
            .filter { deckInfo in
                !(deckInfo.name == "Default" && (noteCountByDeck[deckInfo.id] ?? 0) == 0)
            }
            .max { (noteCountByDeck[$0.id] ?? 0) < (noteCountByDeck[$1.id] ?? 0) }

        return topDeck?.name ?? "Imported Deck"
    }

    private func importedNote(
        from note: AnkiNote,
        model: AnkiModel,
        deckLookup: [Int64: String],
        topDeckFullName: String
    ) -> ImportedNote? {
        guard let mapped = try? NoteFieldMapper.map(note, using: model) else {
            return nil
        }

        let segmented = TargetSegmenter.segment(mapped.target)
        let units = segmented.map { unit -> String in
            switch unit {
            case let .box(str): str
            case let .inline(str): str
            }
        }
        let script = Script(rawValue: TargetSegmenter.classify(mapped.target).rawValue) ?? .mixed
        let noteDeckFullName = note.deckID.flatMap { deckLookup[$0] }
        let sectionName = sectionName(forNoteDeck: noteDeckFullName, topDeckFullName: topDeckFullName)

        return ImportedNote(
            ankiGUID: mapped.ankiGUID,
            target: mapped.target,
            pronunciation: mapped.pronunciation,
            english: mapped.english,
            category: mapped.category,
            hint: mapped.hint,
            audioFilename: mapped.audioFilename,
            sectionName: sectionName,
            units: units,
            script: script
        )
    }

    func apply(_ parsed: ParsedDeck) throws -> UUID {
        let deck = Deck(
            name: parsed.deckName,
            sourceDeckName: parsed.deckName,
            importedAt: Date()
        )
        context.insert(deck)

        var sections: [String: Section] = [:]
        var orderIndex = 0
        for imported in parsed.notes {
            guard let sectionName = imported.sectionName, sections[sectionName] == nil else { continue }
            let section = Section(name: sectionName, orderIndex: orderIndex)
            section.deck = deck
            deck.sections.append(section)
            sections[sectionName] = section
            orderIndex += 1
        }

        for imported in parsed.notes {
            let note = Note(
                id: NoteIdentity.uuid(forAnkiGUID: imported.ankiGUID),
                target: imported.target,
                pronunciation: imported.pronunciation,
                english: imported.english,
                category: imported.category,
                hint: imported.hint,
                audioFilename: imported.audioFilename,
                script: imported.script,
                units: imported.units,
                isDeleted: false
            )

            if let sectionName = imported.sectionName, let section = sections[sectionName] {
                note.section = section
                section.notes.append(note)
            }

            context.insert(note)

            let schedule = CardSchedule()
            schedule.note = note
            note.schedule = schedule
            context.insert(schedule)
        }

        try context.save()
        return deck.id
    }

    private func sectionName(forNoteDeck noteDeckFullName: String?, topDeckFullName: String) -> String? {
        guard let noteDeckFullName, noteDeckFullName != topDeckFullName else {
            return nil
        }

        let prefix = topDeckFullName + "::"
        if noteDeckFullName.hasPrefix(prefix) {
            return String(noteDeckFullName.dropFirst(prefix.count))
        }

        return noteDeckFullName
    }
}
