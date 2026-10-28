import Foundation

struct GameCatalogValidationIssue: Hashable, Sendable {
    let identifier: String
    let message: String
}

/// One entry of `WORDCuratedWordList.json`.
struct GameCatalogWordEntry: Sendable {
    let word: String
    let reference: String
    let verse: String
}

/// One entry of `LockScreenVerses.json`.
struct GameCatalogVerseEntry: Sendable {
    let book: String
    let chapter: Int
    let verse: Int
    let text: String

    var reference: String { "\(book) \(chapter):\(verse)" }
}

enum GameCatalogValidator {
    private static let triviaDifficulties = ["easy", "normal", "hard"]
    private static let whoDifficulties = ["easy", "normal", "hard"]

    static func validateTrivia(
        _ questions: [BibleTriviaQuestion],
        books: [Book],
        minimumQuestionsPerDifficulty: Int = 1
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []
        let knownBookNames = Set(books.map { $0.name.lowercased() })

        for question in questions {
            let identifier = "trivia.\(question.id)"
            let incorrectAnswers = normalizedAnswers(question.incorrectAnswers)

            if question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(identifier: identifier, message: "Question must not be empty."))
            }
            if question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(identifier: identifier, message: "Correct answer must not be empty."))
            }
            if incorrectAnswers.count != question.incorrectAnswers.count || incorrectAnswers.count != Set(incorrectAnswers).count {
                issues.append(.init(identifier: identifier, message: "Incorrect answers must be nonempty and unique."))
            }
            if incorrectAnswers.contains(normalize(question.correctAnswer)) {
                issues.append(.init(identifier: identifier, message: "Correct answer is also an incorrect answer."))
            }

            let difficulty = normalizedDifficulty(question.difficulty)
            if !triviaDifficulties.contains(difficulty) {
                issues.append(.init(identifier: identifier, message: "Unknown difficulty '\(question.difficulty)'."))
            }

            if !knownBookNames.isEmpty, !referenceUsesKnownBook(question.reference, knownBookNames: knownBookNames) {
                issues.append(.init(identifier: identifier, message: "Reference uses an unknown book."))
            }
        }

        appendDuplicateIssues(for: questions.map(\.id), identifier: { "trivia.\($0)" }, issues: &issues)

        appendMinimumPoolIssues(
            for: questions.map { normalizedDifficulty($0.difficulty) },
            categories: triviaDifficulties,
            minimumCount: minimumQuestionsPerDifficulty,
            identifier: { "trivia.\($0)" },
            issues: &issues
        )

        return issues
    }

    static func validateWhoAndHangman(
        characters: [BibleCharacter],
        locations: [BibleLocationChallenge],
        questions: [WhoGameQuestion],
        books: [Book],
        minimumQuestionsPerMode: Int = 1,
        minimumEntriesPerDifficulty: Int = 1
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []
        let characterIDs = Set(characters.map(\.id))
        let knownBookNames = Set(books.map { $0.name.lowercased() })

        appendHangmanIssues(
            characters: characters,
            locations: locations,
            books: books,
            minimumEntriesPerDifficulty: minimumEntriesPerDifficulty,
            issues: &issues
        )
        appendDuplicateIssues(for: questions.map(\.id), identifier: { "who.\($0)" }, issues: &issues)

        for question in questions {
            let identifier = "who.\(question.id)"
            let incorrectAnswers = normalizedAnswers(question.incorrectAnswers)

            if !characterIDs.contains(question.sourcePersonID) {
                issues.append(.init(identifier: identifier, message: "Unknown source person ID \(question.sourcePersonID)."))
            }
            if incorrectAnswers.count != question.incorrectAnswers.count || incorrectAnswers.count != Set(incorrectAnswers).count {
                issues.append(.init(identifier: identifier, message: "Incorrect answers must be nonempty and unique."))
            }
            if incorrectAnswers.contains(normalize(question.correctAnswer)) {
                issues.append(.init(identifier: identifier, message: "Correct answer is also an incorrect answer."))
            }

            let difficulty = normalizedDifficulty(question.difficulty)
            if !whoDifficulties.contains(difficulty) {
                issues.append(.init(identifier: identifier, message: "Unknown difficulty '\(question.difficulty)'."))
            }

            if !knownBookNames.isEmpty, !referenceUsesKnownBook(question.reference, knownBookNames: knownBookNames) {
                issues.append(.init(identifier: identifier, message: "Reference uses an unknown book."))
            }
        }

        for mode in [WhoGameQuestion.Mode.personToFact, .factToPerson] {
            for difficulty in whoDifficulties {
                let count = questions.filter {
                    $0.mode == mode && normalizedDifficulty($0.difficulty) == difficulty
                }.count
                if count < minimumQuestionsPerMode {
                    issues.append(
                        .init(
                            identifier: "\(mode.rawValue).\(difficulty)",
                            message: "Requires at least \(minimumQuestionsPerMode) questions."
                        )
                    )
                }
            }
        }

        return issues
    }

    /// Checks the Today challenge catalog. Takes plain values so the loader's types can stay private.
    static func validateTodayChallengeCatalog(
        gameNames: [String],
        prayerMinimum: Int,
        prayerMaximum: Int,
        prayerFocuses: [String],
        reflectionTasks: [(title: String, detail: String)]
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []

        appendEmptyOrDuplicateIssues(for: gameNames, identifier: "today.gameNames", issues: &issues)
        appendEmptyOrDuplicateIssues(for: prayerFocuses, identifier: "today.prayerFocuses", issues: &issues)
        appendEmptyOrDuplicateIssues(
            for: reflectionTasks.map(\.title),
            identifier: "today.reflectionTasks",
            issues: &issues
        )

        if reflectionTasks.contains(where: { normalize($0.detail).isEmpty }) {
            issues.append(.init(identifier: "today.reflectionTasks", message: "Every task needs a detail."))
        }
        if prayerMinimum < 1 || prayerMinimum > prayerMaximum {
            issues.append(
                .init(
                    identifier: "today.prayerMinutes",
                    message: "Prayer minutes must satisfy 1 <= minimum <= maximum."
                )
            )
        }

        return issues
    }

    /// Checks the curated WORD answers: five letters, unique, and each with a real verse
    /// reference whose text contains the word.
    static func validateCuratedWords(
        _ entries: [GameCatalogWordEntry],
        books: [Book],
        minimumWords: Int = 1
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []

        for entry in entries {
            let word = entry.word.uppercased()
            let identifier = "word.\(word)"

            if word.count != 5 || !word.allSatisfy({ $0 >= "A" && $0 <= "Z" }) {
                issues.append(.init(identifier: identifier, message: "Word must be exactly five letters A–Z."))
            }
            if !entry.verse.lowercased().contains(word.lowercased()) {
                issues.append(.init(identifier: identifier, message: "Verse text does not contain the word."))
            }
            if !books.isEmpty, !referenceExists(entry.reference, in: books) {
                issues.append(.init(identifier: identifier, message: "Reference '\(entry.reference)' does not exist."))
            }
        }

        appendDuplicateIssues(for: entries.map { $0.word.uppercased() }, identifier: { "word.\($0)" }, issues: &issues)

        if entries.count < minimumWords {
            issues.append(.init(identifier: "word", message: "Requires at least \(minimumWords) words."))
        }

        return issues
    }

    /// Checks the Scramble word list: playable answers with no repeats, known difficulties,
    /// and references (when given) that exist. A missing reference is allowed; it means no hint.
    static func validateScrambleWords(
        _ entries: [ScrambleWordEntry],
        books: [Book],
        minimumWordsPerDifficulty: Int = 1
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []

        for entry in entries {
            let identifier = "scramble.\(entry.answer)"

            if entry.answer.count < 2 || !entry.word.allSatisfy({ $0.isLetter || $0 == " " || $0 == "-" }) {
                issues.append(
                    .init(identifier: identifier, message: "Word '\(entry.word)' must be letters, spaces, or hyphens.")
                )
            }
            if normalize(entry.category).isEmpty {
                issues.append(.init(identifier: identifier, message: "Category must not be empty."))
            }
            if !whoDifficulties.contains(normalizedDifficulty(entry.difficulty)) {
                issues.append(.init(identifier: identifier, message: "Unknown difficulty '\(entry.difficulty)'."))
            }
            if let reference = entry.reference, !normalize(reference).isEmpty,
               !books.isEmpty, !referenceExists(reference, in: books) {
                issues.append(.init(identifier: identifier, message: "Reference '\(reference)' does not exist."))
            }
        }

        // "Beth El" and "Bethel" would both be answered as BETHEL.
        appendDuplicateIssues(for: entries.map(\.answer), identifier: { "scramble.\($0)" }, issues: &issues)

        appendMinimumPoolIssues(
            for: entries.map { normalizedDifficulty($0.difficulty) },
            categories: whoDifficulties,
            minimumCount: minimumWordsPerDifficulty,
            identifier: { "scramble.\($0)" },
            issues: &issues
        )

        return issues
    }

    /// Checks the well-known verse list shared by Verse Match and the lock-screen widget.
    static func validateWellKnownVerses(
        _ verses: [GameCatalogVerseEntry],
        books: [Book],
        minimumVerses: Int = 1
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []

        for verse in verses {
            let identifier = "verse.\(verse.reference)"
            if normalize(verse.text).isEmpty {
                issues.append(.init(identifier: identifier, message: "Verse text must not be empty."))
            }
            if !books.isEmpty, !referenceExists(book: verse.book, chapter: verse.chapter, verse: verse.verse, in: books) {
                issues.append(.init(identifier: identifier, message: "Reference does not exist."))
            }
        }

        appendDuplicateIssues(for: verses.map(\.reference), identifier: { "verse.\($0)" }, issues: &issues)

        if verses.count < minimumVerses {
            issues.append(.init(identifier: "verse", message: "Requires at least \(minimumVerses) verses."))
        }

        return issues
    }

    private static func appendHangmanIssues(
        characters: [BibleCharacter],
        locations: [BibleLocationChallenge],
        books: [Book],
        minimumEntriesPerDifficulty: Int,
        issues: inout [GameCatalogValidationIssue]
    ) {
        let knownBookNames = Set(books.map { normalize($0.name) })

        for character in characters {
            let identifier = "person.\(character.id)"
            if normalize(character.name).isEmpty {
                issues.append(.init(identifier: identifier, message: "Name must not be empty."))
            }
            if normalize(character.shortDescription).isEmpty {
                issues.append(.init(identifier: identifier, message: "Description must not be empty."))
            }
            if character.books.isEmpty {
                issues.append(.init(identifier: identifier, message: "Must list at least one book."))
            }
            if !knownBookNames.isEmpty,
               let unknown = character.books.first(where: { !knownBookNames.contains(normalize($0)) }) {
                issues.append(.init(identifier: identifier, message: "Unknown book '\(unknown)'."))
            }
            if !whoDifficulties.contains(normalizedDifficulty(character.difficulty)) {
                issues.append(.init(identifier: identifier, message: "Unknown difficulty '\(character.difficulty)'."))
            }
        }

        for location in locations {
            let identifier = "place.\(location.id)"
            if normalize(location.locationName).isEmpty {
                issues.append(.init(identifier: identifier, message: "Name must not be empty."))
            }
            if normalize(location.shortDescription).isEmpty {
                issues.append(.init(identifier: identifier, message: "Description must not be empty."))
            }
            if !books.isEmpty, !referenceExists(location.scriptureMentioned, in: books) {
                issues.append(
                    .init(identifier: identifier, message: "Reference '\(location.scriptureMentioned)' does not exist.")
                )
            }
            if !whoDifficulties.contains(normalizedDifficulty(location.difficulty)) {
                issues.append(.init(identifier: identifier, message: "Unknown difficulty '\(location.difficulty)'."))
            }
        }

        appendDuplicateIssues(for: characters.map(\.id), identifier: { "person.\($0)" }, issues: &issues)
        appendDuplicateIssues(for: locations.map(\.id), identifier: { "place.\($0)" }, issues: &issues)
        // Two entries with the same name would make Hangman offer the same answer twice.
        appendDuplicateIssues(
            for: characters.map { normalize($0.name) }.filter { !$0.isEmpty },
            identifier: { "person.name.\($0)" },
            issues: &issues
        )
        appendDuplicateIssues(
            for: locations.map { normalize($0.locationName) }.filter { !$0.isEmpty },
            identifier: { "place.name.\($0)" },
            issues: &issues
        )

        appendMinimumPoolIssues(
            for: characters.map { normalizedDifficulty($0.difficulty) },
            categories: whoDifficulties,
            minimumCount: minimumEntriesPerDifficulty,
            identifier: { "person.\($0)" },
            issues: &issues
        )
        appendMinimumPoolIssues(
            for: locations.map { normalizedDifficulty($0.difficulty) },
            categories: whoDifficulties,
            minimumCount: minimumEntriesPerDifficulty,
            identifier: { "place.\($0)" },
            issues: &issues
        )
    }

    private static func appendDuplicateIssues<ID: Hashable>(
        for ids: [ID],
        identifier: (ID) -> String,
        issues: inout [GameCatalogValidationIssue]
    ) {
        var seen = Set<ID>()
        var reported = Set<ID>()
        for id in ids where !seen.insert(id).inserted && reported.insert(id).inserted {
            issues.append(.init(identifier: identifier(id), message: "Duplicate ID."))
        }
    }

    private static func appendEmptyOrDuplicateIssues(
        for values: [String],
        identifier: String,
        issues: inout [GameCatalogValidationIssue]
    ) {
        if values.isEmpty {
            issues.append(.init(identifier: identifier, message: "Must not be empty."))
        }
        if values.contains(where: { normalize($0).isEmpty }) {
            issues.append(.init(identifier: identifier, message: "Contains a blank entry."))
        }
        var seen = Set<String>()
        for value in values.map(normalize) where !value.isEmpty && !seen.insert(value).inserted {
            issues.append(.init(identifier: identifier, message: "Duplicate entry '\(value)'."))
        }
    }

    /// True when every part of a reference names a chapter and verse in `books`. Handles
    /// "Book C:V", ranges ("C:V-V"), and lists ("Book C:V; Book C:V" or "Book C:V; C:V",
    /// where a part without a book continues the previous book).
    private static func referenceExists(_ reference: String, in books: [Book]) -> Bool {
        var currentBook: String?

        for segment in reference.split(separator: ";") {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            var location = Substring(trimmed)
            if let space = trimmed.lastIndex(of: " ") {
                currentBook = bookName(String(trimmed[..<space]))
                location = trimmed[trimmed.index(after: space)...]
            }

            let parts = location.split(separator: ":")
            guard let currentBook,
                  parts.count == 2,
                  let chapter = Int(parts[0]),
                  let verse = Int(parts[1].prefix { $0.isNumber }),
                  referenceExists(book: currentBook, chapter: chapter, verse: verse, in: books) else {
                return false
            }
        }
        return true
    }

    /// Maps the common singular "Psalm" to the canon's "Psalms".
    private static func bookName(_ name: String) -> String {
        normalize(name) == "psalm" ? "Psalms" : name
    }

    private static func referenceExists(book: String, chapter: Int, verse: Int, in books: [Book]) -> Bool {
        guard let match = books.first(where: { normalize($0.name) == normalize(book) }),
              let matchedChapter = match.chapters.first(where: { $0.number == chapter }) else { return false }
        return verse >= 1 && verse <= matchedChapter.verses.count
    }

    private static func appendMinimumPoolIssues(
        for difficulties: [String],
        categories: [String],
        minimumCount: Int,
        identifier: (String) -> String,
        issues: inout [GameCatalogValidationIssue]
    ) {
        for category in categories {
            if difficulties.filter({ $0 == category }).count < minimumCount {
                issues.append(
                    .init(
                        identifier: identifier(category),
                        message: "Requires at least \(minimumCount) questions."
                    )
                )
            }
        }
    }

    private static func normalizedAnswers(_ answers: [String]) -> [String] {
        answers.map(normalize).filter { !$0.isEmpty }
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("") == .orderedSame
            ? ""
            : value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedDifficulty(_ difficulty: String) -> String {
        switch normalize(difficulty) {
        case "medium":
            "normal"
        default:
            normalize(difficulty)
        }
    }

    private static func referenceUsesKnownBook(_ reference: String, knownBookNames: Set<String>) -> Bool {
        let normalizedReference = normalize(reference)
        return knownBookNames.contains { normalizedReference.hasPrefix($0) }
            || normalizedReference.hasPrefix("psalm ")
    }
}
