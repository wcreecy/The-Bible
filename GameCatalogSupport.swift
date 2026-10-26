import Foundation

/// A deterministic random-number generator for game decks and fairness tests.
struct SeededGameRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// Shared deck operations. Production callers use the default system generator; tests can
/// supply a seeded generator to reproduce a sequence exactly.
enum GameSelection {
    static func shuffled<Element>(_ values: [Element]) -> [Element] {
        var generator = SystemRandomNumberGenerator()
        return shuffled(values, using: &generator)
    }

    static func shuffled<Element, Generator: RandomNumberGenerator>(
        _ values: [Element],
        using generator: inout Generator
    ) -> [Element] {
        values.shuffled(using: &generator)
    }

    static func sample<Element, Generator: RandomNumberGenerator>(
        _ values: [Element],
        count: Int,
        using generator: inout Generator
    ) -> [Element] {
        Array(values.shuffled(using: &generator).prefix(max(0, count)))
    }

    static func choice<Element>(_ values: [Element]) -> Element? {
        var generator = SystemRandomNumberGenerator()
        return choice(values, using: &generator)
    }

    static func choice<Element, Generator: RandomNumberGenerator>(
        _ values: [Element],
        using generator: inout Generator
    ) -> Element? {
        guard !values.isEmpty else { return nil }
        return values[Int.random(in: values.indices, using: &generator)]
    }

    /// Draws a round-robin deck from category pools. It avoids exhausting one category while
    /// another still has words, while preserving randomized order within each category.
    static func balancedDeck<Category: Hashable, Element, Generator: RandomNumberGenerator>(
        pools: [Category: [Element]],
        categories: [Category],
        count: Int,
        using generator: inout Generator
    ) -> [Element] {
        var shuffledPools = Dictionary(
            uniqueKeysWithValues: pools.map { category, values in
                (category, values.shuffled(using: &generator))
            }
        )
        var result: [Element] = []
        var nextCategoryIndex = 0

        while result.count < count {
            let available = categories.filter { !(shuffledPools[$0]?.isEmpty ?? true) }
            guard !available.isEmpty else { break }

            let category = available[nextCategoryIndex % available.count]
            nextCategoryIndex += 1
            if let value = shuffledPools[category]?.popLast() {
                result.append(value)
            }
        }

        return result
    }
}

struct GameCatalogValidationIssue: Equatable, Sendable, CustomStringConvertible {
    let catalog: String
    let identifier: String
    let message: String

    var description: String {
        "\(catalog) [\(identifier)]: \(message)"
    }
}

/// Validates the semantic rules shared by the bundled game catalogs. Keep this independent of
/// bundle loading so unit tests can validate small fixtures as well as production data.
enum GameCatalogValidator {
    static func validateTrivia(
        _ questions: [BibleTriviaQuestion],
        books: [Book],
        minimumQuestionsPerDifficulty: Int = 10
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []
        appendDuplicateIDIssues(
            questions.map { String($0.id) },
            catalog: "Trivia",
            issues: &issues
        )

        for question in questions {
            let identifier = String(question.id)
            appendQuestionIssues(
                correctAnswer: question.correctAnswer,
                incorrectAnswers: question.incorrectAnswers,
                reference: question.reference,
                books: books,
                catalog: "Trivia",
                identifier: identifier,
                issues: &issues
            )
            if !["easy", "normal", "hard"].contains(question.difficulty.lowercased()) {
                issues.append(.init(catalog: "Trivia", identifier: identifier, message: "Unknown difficulty \(question.difficulty)."))
            }
        }

        for difficulty in BibleTriviaDifficulty.allCases {
            let count = questions.filter { difficulty.includes($0) }.count
            if count < minimumQuestionsPerDifficulty {
                issues.append(.init(
                    catalog: "Trivia",
                    identifier: difficulty.rawValue,
                    message: "Needs at least \(minimumQuestionsPerDifficulty) eligible questions; found \(count)."
                ))
            }
        }
        return issues
    }

    static func validateWhoAndHangman(
        characters: [BibleCharacter],
        locations: [BibleLocationChallenge],
        questions: [WhoGameQuestion],
        books: [Book],
        minimumQuestionsPerMode: Int = 10
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []
        appendDuplicateIDIssues(characters.map { String($0.id) }, catalog: "Who/Hangman people", issues: &issues)
        appendDuplicateIDIssues(locations.map { String($0.id) }, catalog: "Who/Hangman places", issues: &issues)
        appendDuplicateIDIssues(questions.map(\.id), catalog: "Who", issues: &issues)

        let bookNames = Set(books.map(\.name))
        let characterIDs = Set(characters.map(\.id))
        for character in characters {
            if character.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(catalog: "Who/Hangman people", identifier: String(character.id), message: "Name is empty."))
            }
            for book in character.books where !bookNames.contains(book) {
                issues.append(.init(catalog: "Who/Hangman people", identifier: String(character.id), message: "Unknown book \(book)."))
            }
        }

        for location in locations {
            if location.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(catalog: "Who/Hangman places", identifier: String(location.id), message: "Name is empty."))
            }
            if !hasResolvableLeadingPassage(location.scriptureMentioned, in: books) {
                issues.append(.init(catalog: "Who/Hangman places", identifier: String(location.id), message: "Invalid reference \(location.scriptureMentioned)."))
            }
        }

        for question in questions {
            if !characterIDs.contains(question.sourcePersonID) {
                issues.append(.init(catalog: "Who", identifier: question.id, message: "Unknown source person \(question.sourcePersonID)."))
            }
            appendQuestionIssues(
                correctAnswer: question.correctAnswer,
                incorrectAnswers: question.incorrectAnswers,
                reference: question.reference,
                books: books,
                catalog: "Who",
                identifier: question.id,
                issues: &issues
            )
        }

        for mode in WhoGameQuestion.Mode.allCases {
            for difficulty in ["easy", "normal", "hard"] {
                let count = questions.filter {
                    $0.mode == mode && includesWhoDifficulty($0.difficulty, selectedDifficulty: difficulty)
                }.count
                if count < minimumQuestionsPerMode {
                    issues.append(.init(
                        catalog: "Who",
                        identifier: "\(mode.rawValue).\(difficulty)",
                        message: "Needs at least \(minimumQuestionsPerMode) eligible questions; found \(count)."
                    ))
                }
            }
        }
        return issues
    }

    private static func appendDuplicateIDIssues(
        _ identifiers: [String],
        catalog: String,
        issues: inout [GameCatalogValidationIssue]
    ) {
        for identifier in Set(identifiers) where identifiers.filter({ $0 == identifier }).count > 1 {
            issues.append(.init(catalog: catalog, identifier: identifier, message: "Duplicate ID."))
        }
    }

    private static func appendQuestionIssues(
        correctAnswer: String,
        incorrectAnswers: [String],
        reference: String,
        books: [Book],
        catalog: String,
        identifier: String,
        issues: inout [GameCatalogValidationIssue]
    ) {
        let normalizedCorrect = normalized(correctAnswer)
        let normalizedIncorrect = incorrectAnswers.map(normalized)

        if normalizedCorrect.isEmpty {
            issues.append(.init(catalog: catalog, identifier: identifier, message: "Correct answer is empty."))
        }
        if incorrectAnswers.count < 3 {
            issues.append(.init(catalog: catalog, identifier: identifier, message: "Needs at least three incorrect answers."))
        }
        if Set(normalizedIncorrect).count != normalizedIncorrect.count || normalizedIncorrect.contains(where: \.isEmpty) {
            issues.append(.init(catalog: catalog, identifier: identifier, message: "Incorrect answers must be nonempty and unique."))
        }
        if normalizedIncorrect.contains(normalizedCorrect) {
            issues.append(.init(catalog: catalog, identifier: identifier, message: "Correct answer is also an incorrect answer."))
        }
        if !hasResolvableLeadingPassage(reference, in: books) {
            issues.append(.init(catalog: catalog, identifier: identifier, message: "Invalid reference \(reference)."))
        }
    }

    /// Catalog references may use ranges, comma continuations, or semicolon-separated passages.
    /// Resolve the first explicit passage against the loaded canon; later clauses inherit that
    /// citation grammar and remain editorial display text.
    private static func hasResolvableLeadingPassage(_ reference: String, in books: [Book]) -> Bool {
        let firstClause = reference
            .replacingOccurrences(of: "–", with: "-")
            .split(separator: ";", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let citation = firstClause
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        let parts = citation.split(whereSeparator: \Character.isWhitespace).map(String.init)
        guard let locationIndex = parts.lastIndex(where: { $0.first?.isNumber == true }) else {
            return false
        }

        let locationPrefix = parts[locationIndex]
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,:;")) ?? ""
        guard !locationPrefix.isEmpty else { return false }

        let bookName = parts[..<locationIndex].joined(separator: " ")
        return !bookName.isEmpty
            && BibleReferenceParser.reference(for: "\(bookName) \(locationPrefix)", in: books) != nil
    }

    private static func includesWhoDifficulty(_ value: String, selectedDifficulty: String) -> Bool {
        switch value.lowercased() {
        case "easy":
            true
        case "medium", "normal":
            selectedDifficulty != "easy"
        default:
            selectedDifficulty == "hard"
        }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
