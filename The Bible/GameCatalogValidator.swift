import Foundation

struct GameCatalogValidationIssue: Hashable, Sendable {
    let identifier: String
    let message: String
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

        for id in Set(questions.map(\.id)) where questions.filter({ $0.id == id }).count > 1 {
            issues.append(.init(identifier: "trivia.\(id)", message: "Duplicate ID."))
        }

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
        minimumQuestionsPerMode: Int = 1
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []
        let characterIDs = Set(characters.map(\.id))
        let knownBookNames = Set(books.map { $0.name.lowercased() })

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
    }
}
