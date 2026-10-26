import Foundation

struct GameCatalogValidationIssue: Hashable, Sendable, CustomStringConvertible {
    let identifier: String
    let message: String

    var description: String {
        "\(identifier): \(message)"
    }
}

enum GameCatalogValidator {
    private static let supportedDifficulties: Set<String> = ["easy", "normal", "medium", "hard"]

    static func validateTrivia(
        _ questions: [BibleTriviaQuestion],
        books: [Book],
        minimumQuestionsPerDifficulty: Int = 1
    ) -> [GameCatalogValidationIssue] {
        var issues = validate(
            questions,
            identifier: { "trivia.\($0.id)" },
            id: { $0.id },
            difficulty: { $0.difficulty },
            correctAnswer: { $0.correctAnswer },
            incorrectAnswers: { $0.incorrectAnswers }
        )

        for difficulty in ["easy", "normal", "hard"] {
            let count = questions.count { $0.difficulty.caseInsensitiveCompare(difficulty) == .orderedSame }
            if count < minimumQuestionsPerDifficulty {
                issues.append(
                    GameCatalogValidationIssue(
                        identifier: "trivia.\(difficulty)",
                        message: "Expected at least \(minimumQuestionsPerDifficulty) questions, found \(count)."
                    )
                )
            }
        }

        return issues
    }

    static func validateWhoAndHangman(
        characters: [BibleCharacter],
        locations: [BibleLocationChallenge],
        questions: [WhoGameQuestion],
        books: [Book],
        minimumQuestionsPerMode: Int = 1
    ) -> [GameCatalogValidationIssue] {
        var issues = validate(
            questions,
            identifier: { "who.\($0.id)" },
            id: { $0.id },
            difficulty: { $0.difficulty },
            correctAnswer: { $0.correctAnswer },
            incorrectAnswers: { $0.incorrectAnswers }
        )

        let characterIDs = Set(characters.map(\.id))
        for question in questions where !characterIDs.contains(question.sourcePersonID) {
            issues.append(
                GameCatalogValidationIssue(
                    identifier: "who.\(question.id)",
                    message: "Unknown source person ID \(question.sourcePersonID)."
                )
            )
        }

        for mode in WhoGameQuestion.Mode.allCases {
            for difficulty in ["easy", "medium", "hard"] {
                let count = questions.count {
                    $0.mode == mode && $0.difficulty.caseInsensitiveCompare(difficulty) == .orderedSame
                }
                if count < minimumQuestionsPerMode {
                    issues.append(
                        GameCatalogValidationIssue(
                            identifier: "\(mode.rawValue).\(difficulty)",
                            message: "Expected at least \(minimumQuestionsPerMode) questions, found \(count)."
                        )
                    )
                }
            }
        }

        return issues
    }

    private static func validate<Question, ID: Hashable>(
        _ questions: [Question],
        identifier: (Question) -> String,
        id: (Question) -> ID,
        difficulty: (Question) -> String,
        correctAnswer: (Question) -> String,
        incorrectAnswers: (Question) -> [String]
    ) -> [GameCatalogValidationIssue] {
        var issues: [GameCatalogValidationIssue] = []
        var seenIDs: Set<ID> = []

        for question in questions {
            let questionIdentifier = identifier(question)
            if !seenIDs.insert(id(question)).inserted {
                issues.append(
                    GameCatalogValidationIssue(identifier: questionIdentifier, message: "Duplicate ID.")
                )
            }

            let normalizedCorrectAnswer = correctAnswer(question).normalizedGameAnswer
            let normalizedIncorrectAnswers = incorrectAnswers(question).map(\.normalizedGameAnswer)
            if normalizedIncorrectAnswers.contains(normalizedCorrectAnswer) {
                issues.append(
                    GameCatalogValidationIssue(
                        identifier: questionIdentifier,
                        message: "Correct answer is also an incorrect answer."
                    )
                )
            }

            if normalizedIncorrectAnswers.isEmpty || Set(normalizedIncorrectAnswers).count != normalizedIncorrectAnswers.count {
                issues.append(
                    GameCatalogValidationIssue(
                        identifier: questionIdentifier,
                        message: "Incorrect answers must be nonempty and unique."
                    )
                )
            }

            if !supportedDifficulties.contains(difficulty(question).lowercased()) {
                issues.append(
                    GameCatalogValidationIssue(
                        identifier: questionIdentifier,
                        message: "Unknown difficulty '\(difficulty(question))'."
                    )
                )
            }
        }

        return issues
    }
}

private extension String {
    var normalizedGameAnswer: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
