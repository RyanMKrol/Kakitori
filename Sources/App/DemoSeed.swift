#if DEBUG
    import Foundation
    import SwiftData

    enum DemoSeed {
        @MainActor
        static func seedIfNeeded(context: ModelContext, clock: AppClock) {
            guard UserDefaults.standard.bool(forKey: "seedDemoData") else {
                return
            }

            let request = FetchDescriptor<Deck>(predicate: #Predicate { $0.sourceDeckName == "Demo::Hiragana" })
            guard (try? context.fetch(request).isEmpty) ?? true else {
                return
            }

            seed(context: context, clock: clock)
        }

        @MainActor
        static func seed(context: ModelContext, clock: AppClock) {
            let request = FetchDescriptor<Deck>(predicate: #Predicate { $0.sourceDeckName == "Demo::Hiragana" })
            guard (try? context.fetch(request).isEmpty) ?? true else {
                return
            }

            let now = clock.now()

            let hiraganaDeck = seedHiragana(now: now)
            let katakanaDeck = seedKatakana(now: now)
            let kanjiDeck = seedKanji(now: now)

            context.insert(hiraganaDeck)
            context.insert(katakanaDeck)
            context.insert(kanjiDeck)

            seedDailyStats(context: context, now: now, clock: clock)
        }

        // MARK: - Hiragana Deck

        private static func seedHiragana(now: Date) -> Deck {
            let section = Section(name: "", orderIndex: 0)
            let deck = Deck(
                name: "Hiragana",
                jpTitle: "ひらがな",
                sourceDeckName: "Demo::Hiragana",
                importedAt: now,
                sections: [section]
            )
            section.deck = deck

            let cards = [
                ("あ", "a"),
                ("い", "i"),
                ("う", "u"),
                ("え", "e"),
            ]
            for (index, (target, pronunciation)) in cards.enumerated() {
                let note = Note(
                    target: target,
                    pronunciation: pronunciation,
                    script: .hiragana,
                    units: [target]
                )

                let schedule = scheduleForHiraganaCard(at: index, now: now)
                schedule.note = note
                note.schedule = schedule
                note.section = section
                section.notes.append(note)
            }

            return deck
        }

        private static func scheduleForHiraganaCard(at index: Int, now: Date) -> CardSchedule {
            switch index {
            case 0:
                CardSchedule(state: .new)
            case 1:
                CardSchedule(
                    state: .learning,
                    stepIndex: 1,
                    dueAt: now.addingTimeInterval(600)
                )
            case 2:
                CardSchedule(
                    state: .review,
                    stepIndex: 0,
                    easeFactor: 2.5,
                    intervalDays: 8,
                    dueAt: now.addingTimeInterval(-86400),
                    lapses: 0
                )
            default:
                CardSchedule(
                    state: .review,
                    stepIndex: 0,
                    easeFactor: 2.5,
                    intervalDays: 4,
                    dueAt: now.addingTimeInterval(259_200),
                    lapses: 0
                )
            }
        }

        // MARK: - Katakana Deck

        private static func seedKatakana(now: Date) -> Deck {
            let section = Section(name: "", orderIndex: 0)
            let deck = Deck(
                name: "Katakana",
                jpTitle: "カタカナ",
                sourceDeckName: "Demo::Katakana",
                importedAt: now,
                sections: [section]
            )
            section.deck = deck

            let cards = [
                ("ア", "a"),
                ("イ", "i"),
                ("ウ", "u"),
            ]
            for (index, (target, pronunciation)) in cards.enumerated() {
                let note = Note(
                    target: target,
                    pronunciation: pronunciation,
                    script: .katakana,
                    units: [target]
                )

                let schedule = scheduleForKatakanaCard(at: index, now: now)
                schedule.note = note
                note.schedule = schedule
                note.section = section
                section.notes.append(note)
            }

            return deck
        }

        private static func scheduleForKatakanaCard(at index: Int, now: Date) -> CardSchedule {
            switch index {
            case 0:
                CardSchedule(state: .learning, stepIndex: 1, dueAt: now.addingTimeInterval(600))
            case 1:
                CardSchedule(
                    state: .review,
                    stepIndex: 0,
                    easeFactor: 2.5,
                    intervalDays: 12,
                    dueAt: now.addingTimeInterval(259_200),
                    lapses: 0
                )
            default:
                CardSchedule(state: .new)
            }
        }

        // MARK: - Kanji Deck

        private static func seedKanji(now: Date) -> Deck {
            let section = Section(name: "", orderIndex: 0)
            let deck = Deck(
                name: "Kanji",
                jpTitle: "漢字",
                sourceDeckName: "Demo::Kanji",
                importedAt: now,
                sections: [section]
            )
            section.deck = deck

            let cards = [
                ("日", "sun", nil),
                ("月", "moon", nil),
                ("語", "language", "ご"),
            ]
            for (index, (target, english, pronunciation)) in cards.enumerated() {
                let note = Note(
                    target: target,
                    pronunciation: pronunciation,
                    english: english,
                    script: .kanji,
                    units: [target]
                )

                let schedule = scheduleForKanjiCard(at: index, now: now)
                schedule.note = note
                note.schedule = schedule
                note.section = section
                section.notes.append(note)
            }

            return deck
        }

        private static func scheduleForKanjiCard(at index: Int, now: Date) -> CardSchedule {
            switch index {
            case 0:
                CardSchedule(state: .new)
            case 1:
                CardSchedule(
                    state: .review,
                    stepIndex: 0,
                    easeFactor: 2.5,
                    intervalDays: 6,
                    dueAt: now.addingTimeInterval(-86400),
                    lapses: 0
                )
            default:
                CardSchedule(
                    state: .learning,
                    stepIndex: 1,
                    dueAt: now.addingTimeInterval(600)
                )
            }
        }

        // MARK: - Daily Stats

        @MainActor
        private static func seedDailyStats(context: ModelContext, now: Date, clock: AppClock) {
            let today = clock.adjustedDay(for: now)
            let yesterday = clock.adjustedDay(for: now.addingTimeInterval(-86400))
            let twoDaysAgo = clock.adjustedDay(for: now.addingTimeInterval(-172_800))

            let stats1 = DailyStats(
                day: today,
                cardsWritten: 12,
                newIntroduced: 3,
                reviewsDone: 9,
                secondsStudied: 360
            )
            let stats2 = DailyStats(
                day: yesterday,
                cardsWritten: 8,
                newIntroduced: 2,
                reviewsDone: 6,
                secondsStudied: 240
            )
            let stats3 = DailyStats(
                day: twoDaysAgo,
                cardsWritten: 15,
                newIntroduced: 5,
                reviewsDone: 10,
                secondsStudied: 450
            )

            context.insert(stats1)
            context.insert(stats2)
            context.insert(stats3)

            try? context.save()
        }
    }
#endif
