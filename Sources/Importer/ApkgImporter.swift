import Foundation
import SwiftData

enum ImporterError: Error, Equatable {
    case badZip
    case noAnkiBuilderModel
    case zeroNotes

    /// User-facing description (surfaced if a bundled deck fails to load).
    var userMessage: String {
        switch self {
        case .badZip:
            "This file could not be read as an Anki deck."
        case .noAnkiBuilderModel:
            "This deck has no field Kakitori can use as a writing target."
        case .zeroNotes:
            "This deck has no cards to import."
        }
    }
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
    let extractionDirectory: URL
    /// Idempotence key for re-import matching. Defaults to `deckName`; a split deck overrides it so
    /// each split (e.g. "Kakitori Foundations::Hiragana") matches its own existing deck on re-import.
    let sourceKey: String?
    /// User-facing deck name. Defaults to `deckName`; overridden to a friendly name (e.g. "Hiragana").
    let displayName: String?
    /// Optional Japanese title shown on the deck card (e.g. ひらがな).
    let jpTitle: String?

    init(
        deckName: String,
        notes: [ImportedNote],
        extractionDirectory: URL,
        sourceKey: String? = nil,
        displayName: String? = nil,
        jpTitle: String? = nil
    ) {
        self.deckName = deckName
        self.notes = notes
        self.extractionDirectory = extractionDirectory
        self.sourceKey = sourceKey
        self.displayName = displayName
        self.jpTitle = jpTitle
    }

    /// The resolved re-import key and display name.
    var resolvedSourceName: String {
        sourceKey ?? deckName
    }

    var resolvedDisplayName: String {
        displayName ?? deckName
    }
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
        defer { try? FileManager.default.removeItem(at: parsed.extractionDirectory) }

        let deckID = try apply(parsed)

        let manifestURL = parsed.extractionDirectory.appendingPathComponent("media")
        try MediaStore(baseURL: mediaBaseURL).copyMedia(
            manifestURL: manifestURL,
            payloadDirectory: parsed.extractionDirectory,
            deckID: deckID
        )
    }

    /// Import ONE source `.apkg` but split its top-level sections into SEPARATE decks — e.g. the
    /// Foundations deck becomes independent Hiragana / Katakana / Kanji decks, each carrying only its
    /// own notes and audio. The source deck is used purely as a content pool, not surfaced directly.
    /// `titles` maps a section name (as produced by the importer, e.g. "Hiragana") to its friendly
    /// display name + optional JP title; a section with no entry uses its own name and no JP title.
    /// Idempotent per split deck (sourceDeckName = "<root>::<section>").
    func importDeckSplitBySection(
        from url: URL,
        titles: [String: (name: String, jpTitle: String?)] = [:]
    ) async throws {
        let parsed = try parse(url: url)
        defer { try? FileManager.default.removeItem(at: parsed.extractionDirectory) }

        let manifestURL = parsed.extractionDirectory.appendingPathComponent("media")
        let fullManifest = (try? MediaStore.readManifest(at: manifestURL)) ?? [:]
        let mediaStore = MediaStore(baseURL: mediaBaseURL)

        // Group notes by section, preserving first-seen section order.
        var order: [String] = []
        var groups: [String: [ImportedNote]] = [:]
        for note in parsed.notes {
            let key = note.sectionName ?? parsed.deckName
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(note)
        }

        for key in order {
            let notes = groups[key] ?? []
            let split = ParsedDeck(
                deckName: key,
                notes: notes,
                extractionDirectory: parsed.extractionDirectory,
                sourceKey: "\(parsed.deckName)::\(key)",
                displayName: titles[key]?.name ?? key,
                jpTitle: titles[key]?.jpTitle ?? nil
            )
            let deckID = try apply(split)

            // Copy only this split deck's audio: filter the manifest to files it references.
            let wanted = Set(notes.compactMap(\.audioFilename))
            let subManifest = fullManifest.filter { wanted.contains($0.value) }
            try mediaStore.copyMedia(
                manifest: subManifest,
                payloadDirectory: parsed.extractionDirectory,
                deckID: deckID
            )
        }
    }

    func parse(url: URL) throws -> ParsedDeck {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try extract(url, to: tempDir)
            let collection = try openCollection(at: collectionURL(in: tempDir))

            guard let targetModel = collection.models
                .first(where: { NoteFieldMapper.hasMappableTarget($0.fieldNames) })
            else {
                throw ImporterError.noAnkiBuilderModel
            }

            let topDeckFullName = topDeckFullName(in: collection)
            let deckName = topDeckFullName.components(separatedBy: "::").first ?? topDeckFullName
            let deckLookup = Dictionary(uniqueKeysWithValues: collection.decks.map { ($0.id, $0.name) })

            let importedNotes = collection.notes
                .filter { $0.modelID == targetModel.id }
                .compactMap { note in
                    importedNote(
                        from: note,
                        model: targetModel,
                        deckLookup: deckLookup,
                        topDeckFullName: topDeckFullName
                    )
                }

            return ParsedDeck(deckName: deckName, notes: importedNotes, extractionDirectory: tempDir)
        } catch {
            try? FileManager.default.removeItem(at: tempDir)
            throw error
        }
    }

    /// The collection database inside an extracted `.apkg`. Modern Anki exports carry the real data in
    /// `collection.anki21` and ship `collection.anki2` only as a legacy stub, so prefer the former.
    private func collectionURL(in dir: URL) -> URL {
        let anki21 = dir.appendingPathComponent("collection.anki21")
        if FileManager.default.fileExists(atPath: anki21.path) {
            return anki21
        }
        return dir.appendingPathComponent("collection.anki2")
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

        let fullName = topDeck?.name ?? "Imported Deck"
        // The busiest deck is often a SUBDECK (e.g. "Tofugu Hiragana Anki Deck::1: Hiragana"). We import
        // its top-level root as the deck; every subdeck beneath it becomes a section. Returning the root
        // (not the busiest subdeck) is what lets `sectionName` assign a section to ALL notes — otherwise
        // notes in the busiest subdeck get no section and vanish from section-based UI counts.
        return fullName.components(separatedBy: "::").first ?? fullName
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
        let sourceName = parsed.resolvedSourceName
        let existingDeckDescriptor = FetchDescriptor<Deck>(
            predicate: #Predicate { $0.sourceDeckName == sourceName }
        )
        if let existingDeck = try context.fetch(existingDeckDescriptor).first {
            return try reimport(parsed, into: existingDeck)
        }
        return try firstImport(parsed)
    }

    private func firstImport(_ parsed: ParsedDeck) throws -> UUID {
        let deck = Deck(
            name: parsed.resolvedDisplayName,
            jpTitle: parsed.jpTitle,
            sourceDeckName: parsed.resolvedSourceName,
            importedAt: Date()
        )
        context.insert(deck)

        var sections: [String: Section] = [:]
        for imported in parsed.notes {
            _ = section(named: imported.sectionName, in: deck, sections: &sections)
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
                isSoftDeleted: false,
                deck: deck
            )

            if let section = section(named: imported.sectionName, in: deck, sections: &sections) {
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

    private func reimport(_ parsed: ParsedDeck, into deck: Deck) throws -> UUID {
        deck.importedAt = Date()
        // Refresh the friendly display name / JP title so existing installs pick up renames on re-import.
        deck.name = parsed.resolvedDisplayName
        deck.jpTitle = parsed.jpTitle

        var sections = Dictionary(uniqueKeysWithValues: deck.sections.map { ($0.name, $0) })
        let deckID = deck.id
        let existingNotesDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.deck?.id == deckID }
        )
        let existingNotesByID = try Dictionary(
            uniqueKeysWithValues: context.fetch(existingNotesDescriptor).map { ($0.id, $0) }
        )

        var incomingIDs = Set<UUID>()

        for imported in parsed.notes {
            let noteID = NoteIdentity.uuid(forAnkiGUID: imported.ankiGUID)
            incomingIDs.insert(noteID)

            if let note = existingNotesByID[noteID] {
                update(note, with: imported, in: deck, sections: &sections)
            } else {
                insertNote(id: noteID, imported: imported, in: deck, sections: &sections)
            }
        }

        for (id, note) in existingNotesByID where !incomingIDs.contains(id) {
            note.isSoftDeleted = true
        }

        try context.save()
        return deck.id
    }

    private func update(
        _ note: Note,
        with imported: ImportedNote,
        in deck: Deck,
        sections: inout [String: Section]
    ) {
        note.target = imported.target
        note.pronunciation = imported.pronunciation
        note.english = imported.english
        note.category = imported.category
        note.hint = imported.hint
        note.audioFilename = imported.audioFilename
        note.units = imported.units
        note.script = imported.script
        note.isSoftDeleted = false

        let newSection = section(named: imported.sectionName, in: deck, sections: &sections)
        if note.section !== newSection {
            note.section?.notes.removeAll { $0.id == note.id }
            note.section = newSection
            newSection?.notes.append(note)
        }
    }

    private func insertNote(
        id: UUID,
        imported: ImportedNote,
        in deck: Deck,
        sections: inout [String: Section]
    ) {
        let note = Note(
            id: id,
            target: imported.target,
            pronunciation: imported.pronunciation,
            english: imported.english,
            category: imported.category,
            hint: imported.hint,
            audioFilename: imported.audioFilename,
            script: imported.script,
            units: imported.units,
            isSoftDeleted: false,
            deck: deck
        )

        if let newSection = section(named: imported.sectionName, in: deck, sections: &sections) {
            note.section = newSection
            newSection.notes.append(note)
        }

        context.insert(note)

        let schedule = CardSchedule(state: .new)
        schedule.note = note
        note.schedule = schedule
        context.insert(schedule)
    }

    private func section(
        named sectionName: String?,
        in deck: Deck,
        sections: inout [String: Section]
    ) -> Section? {
        guard let sectionName else { return nil }

        if let existing = sections[sectionName] {
            return existing
        }

        let section = Section(name: sectionName, orderIndex: sections.count)
        section.deck = deck
        deck.sections.append(section)
        sections[sectionName] = section
        return section
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
