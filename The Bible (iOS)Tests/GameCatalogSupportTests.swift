import Foundation
import Testing
@testable import Bible

@MainActor
struct GameCatalogSupportTests {
    @Test
    func bundledTriviaAndWhoCatalogsPassValidation() throws {
        let triviaURL = try #require(Bundle.main.url(forResource: "BibleTriviaQuestions", withExtension: "json"))
        let triviaData = try Data(contentsOf: triviaURL)
        let trivia = try JSONDecoder().decode([BibleTriviaQuestion].self, from: triviaData)

        #expect(GameCatalogValidator.validateTrivia(trivia, books: BibleData.books).isEmpty)

        let whoIssues = GameCatalogValidator.validateWhoAndHangman(
            characters: GameDataLoaders.loadCharacters(),
            locations: GameDataLoaders.loadLocationChallenges(),
            questions: GameDataLoaders.loadWhoQuestions(),
            books: BibleData.books
        )
        #expect(whoIssues.isEmpty)
    }

    @Test
    func triviaValidationDetectsDuplicateIDsAndAmbiguousAnswers() {
        let questions = [
            BibleTriviaQuestion(
                id: 1,
                question: "Question one",
                correctAnswer: "Noah",
                incorrectAnswers: ["Moses", "Noah", "Moses"],
                reference: "Unknown 1:1",
                difficulty: "easy"
            ),
            BibleTriviaQuestion(
                id: 1,
                question: "Question two",
                correctAnswer: "Abraham",
                incorrectAnswers: ["Isaac", "Jacob", "Joseph"],
                reference: "Unknown 1:1",
                difficulty: "unexpected"
            )
        ]

        let issues = GameCatalogValidator.validateTrivia(
            questions,
            books: [],
            minimumQuestionsPerDifficulty: 1
        )

        #expect(issues.contains { $0.message == "Duplicate ID." })
        #expect(issues.contains { $0.message == "Correct answer is also an incorrect answer." })
        #expect(issues.contains { $0.message == "Incorrect answers must be nonempty and unique." })
        #expect(issues.contains { $0.message.contains("Unknown difficulty") })
    }

    @Test
    func whoValidationDetectsUnknownSourcesAndInsufficientModePools() {
        let question = WhoGameQuestion(
            id: "who-1",
            mode: .factToPerson,
            difficulty: "easy",
            question: "Built an ark",
            correctAnswer: "Noah",
            incorrectAnswers: ["Moses", "Abraham", "David"],
            reference: "Unknown 1:1",
            sourcePersonID: 99
        )

        let issues = GameCatalogValidator.validateWhoAndHangman(
            characters: [],
            locations: [],
            questions: [question],
            books: [],
            minimumQuestionsPerMode: 2
        )

        #expect(issues.contains { $0.message.contains("Unknown source person") })
        #expect(issues.contains { $0.identifier == "person_to_fact.easy" })
    }
}
