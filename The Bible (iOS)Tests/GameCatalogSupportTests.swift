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
    func seededSelectionIsReproducible() {
        var firstGenerator = SeededGameRandomNumberGenerator(seed: 42)
        var secondGenerator = SeededGameRandomNumberGenerator(seed: 42)

        let first = GameSelection.sample(Array(0..<20), count: 8, using: &firstGenerator)
        let second = GameSelection.sample(Array(0..<20), count: 8, using: &secondGenerator)

        #expect(first == second)
        #expect(Set(first).count == first.count)
    }

    @Test
    func balancedDeckRotatesAcrossAvailableCategories() {
        var generator = SeededGameRandomNumberGenerator(seed: 7)
        let deck = GameSelection.balancedDeck(
            pools: [
                "people": ["P1", "P2"],
                "places": ["L1", "L2"],
                "books": ["B1", "B2"]
            ],
            categories: ["people", "places", "books"],
            count: 6,
            using: &generator
        )

        #expect(deck.count == 6)
        #expect(deck.filter { $0.hasPrefix("P") }.count == 2)
        #expect(deck.filter { $0.hasPrefix("L") }.count == 2)
        #expect(deck.filter { $0.hasPrefix("B") }.count == 2)
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
