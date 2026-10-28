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

        // Minimums sit well below today's pool sizes but high enough to catch a gutted deck.
        let triviaIssues = GameCatalogValidator.validateTrivia(
            trivia,
            books: BibleData.books,
            minimumQuestionsPerDifficulty: 100
        )
        #expect(triviaIssues.isEmpty, "\(triviaIssues)")

        let whoIssues = GameCatalogValidator.validateWhoAndHangman(
            characters: GameDataLoaders.loadCharacters(),
            locations: GameDataLoaders.loadLocationChallenges(),
            questions: GameDataLoaders.loadWhoQuestions(),
            books: BibleData.books,
            minimumQuestionsPerMode: 30,
            minimumEntriesPerDifficulty: 30
        )
        #expect(whoIssues.isEmpty, "\(whoIssues)")
    }

    @Test
    func bundledTodayChallengeCatalogPassesValidation() throws {
        struct Catalog: Decodable {
            struct Prayer: Decodable { let minimum: Int; let maximum: Int }
            struct Reflection: Decodable { let title: String; let detail: String }
            let gameNames: [String]
            let prayerMinutes: Prayer
            let prayerFocuses: [String]
            let reflectionTasks: [Reflection]
        }

        let url = try #require(Bundle.main.url(forResource: "TodayChallengeCatalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))

        let issues = GameCatalogValidator.validateTodayChallengeCatalog(
            gameNames: catalog.gameNames,
            prayerMinimum: catalog.prayerMinutes.minimum,
            prayerMaximum: catalog.prayerMinutes.maximum,
            prayerFocuses: catalog.prayerFocuses,
            reflectionTasks: catalog.reflectionTasks.map { ($0.title, $0.detail) }
        )
        #expect(issues.isEmpty, "\(issues)")
    }

    @Test
    func bundledScrambleWordsPassValidation() {
        let words = GameDataLoaders.loadScrambleWords()

        // One session draws 10 words, so each difficulty needs at least that many.
        let issues = GameCatalogValidator.validateScrambleWords(
            words,
            books: BibleData.books,
            minimumWordsPerDifficulty: 10
        )
        #expect(issues.isEmpty, "\(issues)")
        #expect(words.count > 900)
    }

    @Test
    func scrambleAnswersKeepOnlyLetters() {
        func answer(_ word: String) -> String {
            ScrambleWordEntry(word: word, category: "Place", difficulty: "hard", reference: nil).answer
        }

        #expect(answer("Ben-hadad") == "BENHADAD")
        #expect(answer("Red Sea") == "REDSEA")
        #expect(answer("Aaron") == "AARON")
    }

    @Test
    func scrambleValidationDetectsBadEntries() {
        let entries = [
            ScrambleWordEntry(word: "Bethel", category: "Place", difficulty: "easy", reference: "Genesis 12:8"),
            ScrambleWordEntry(word: "Beth El", category: "Place", difficulty: "easy", reference: nil),
            ScrambleWordEntry(word: "Noah2", category: "", difficulty: "legendary", reference: "Genesis 99:1"),
            ScrambleWordEntry(word: "Eden", category: "Place", difficulty: "easy", reference: "")
        ]

        let issues = GameCatalogValidator.validateScrambleWords(
            entries,
            books: BibleData.books,
            minimumWordsPerDifficulty: 2
        )

        #expect(issues.contains { $0.identifier == "scramble.BETHEL" && $0.message == "Duplicate ID." })
        #expect(issues.contains { $0.message.contains("letters, spaces, or hyphens") })
        #expect(issues.contains { $0.message == "Category must not be empty." })
        #expect(issues.contains { $0.message.contains("Unknown difficulty") })
        #expect(issues.contains { $0.message.contains("does not exist") })
        #expect(issues.contains { $0.identifier == "scramble.hard" })
        // A missing or blank reference only means no hint.
        #expect(!issues.contains { $0.identifier == "scramble.EDEN" })
    }

    @Test
    func bundledCuratedWordsPassValidation() throws {
        struct Entry: Decodable { let word: String; let reference: String; let verse: String }

        let url = try #require(Bundle.main.url(forResource: "WORDCuratedWordList", withExtension: "json"))
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))

        let issues = GameCatalogValidator.validateCuratedWords(
            entries.map { GameCatalogWordEntry(word: $0.word, reference: $0.reference, verse: $0.verse) },
            books: BibleData.books
        )
        #expect(issues.isEmpty, "\(issues)")
    }

    @Test
    func bundledWellKnownVersesPassValidation() throws {
        struct Entry: Decodable { let book: String; let chapter: Int; let verse: Int; let text: String }

        let url = try #require(Bundle.main.url(forResource: "LockScreenVerses", withExtension: "json"))
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))

        let issues = GameCatalogValidator.validateWellKnownVerses(
            entries.map { GameCatalogVerseEntry(book: $0.book, chapter: $0.chapter, verse: $0.verse, text: $0.text) },
            books: BibleData.books
        )
        #expect(issues.isEmpty, "\(issues)")
    }

    @Test
    func todayChallengeValidationDetectsBadCatalogs() {
        let issues = GameCatalogValidator.validateTodayChallengeCatalog(
            gameNames: ["Quiz", " quiz "],
            prayerMinimum: 10,
            prayerMaximum: 5,
            prayerFocuses: [],
            reflectionTasks: [("Be kind", "")]
        )

        #expect(issues.contains { $0.identifier == "today.gameNames" && $0.message.contains("Duplicate") })
        #expect(issues.contains { $0.identifier == "today.prayerFocuses" })
        #expect(issues.contains { $0.identifier == "today.prayerMinutes" })
        #expect(issues.contains { $0.message == "Every task needs a detail." })
    }

    @Test
    func curatedWordValidationDetectsBadEntries() {
        let issues = GameCatalogValidator.validateCuratedWords(
            [
                GameCatalogWordEntry(word: "grace", reference: "Genesis 1:1", verse: "In the beginning"),
                GameCatalogWordEntry(word: "GRACE", reference: "Genesis 99:1", verse: "Grace be with you"),
                GameCatalogWordEntry(word: "Noah1", reference: "Genesis 1:1", verse: "Noah1")
            ],
            books: BibleData.books
        )

        #expect(issues.contains { $0.message == "Verse text does not contain the word." })
        #expect(issues.contains { $0.message.contains("does not exist") })
        #expect(issues.contains { $0.message == "Duplicate ID." })
        #expect(issues.contains { $0.message.contains("five letters") })
    }

    @Test
    func wellKnownVerseValidationDetectsBadEntries() {
        let issues = GameCatalogValidator.validateWellKnownVerses(
            [
                GameCatalogVerseEntry(book: "Genesis", chapter: 1, verse: 1, text: "In the beginning"),
                GameCatalogVerseEntry(book: "Genesis", chapter: 1, verse: 1, text: " "),
                GameCatalogVerseEntry(book: "Nowhere", chapter: 1, verse: 1, text: "Text")
            ],
            books: BibleData.books,
            minimumVerses: 5
        )

        #expect(issues.contains { $0.message == "Verse text must not be empty." })
        #expect(issues.contains { $0.message == "Reference does not exist." })
        #expect(issues.contains { $0.message == "Duplicate ID." })
        #expect(issues.contains { $0.identifier == "verse" })
    }

    @Test
    func hangmanValidationDetectsBadEntries() {
        let characters = [
            BibleCharacter(id: 1, name: "Noah", books: ["Genesis"], shortDescription: "Built an ark", difficulty: "Easy"),
            BibleCharacter(id: 1, name: " noah ", books: ["Nowhere"], shortDescription: "", difficulty: "Legendary")
        ]
        let locations = [
            BibleLocationChallenge(
                id: 7,
                locationName: "Eden",
                scriptureMentioned: "Genesis 2:8",
                shortDescription: "A garden",
                difficulty: "Medium"
            ),
            BibleLocationChallenge(
                id: 8,
                locationName: "Atlantis",
                scriptureMentioned: "Genesis 99:1",
                shortDescription: "A city",
                difficulty: "Hard"
            )
        ]

        let issues = GameCatalogValidator.validateWhoAndHangman(
            characters: characters,
            locations: locations,
            questions: [],
            books: BibleData.books,
            minimumQuestionsPerMode: 0,
            minimumEntriesPerDifficulty: 2
        )

        #expect(issues.contains { $0.identifier == "person.1" && $0.message == "Duplicate ID." })
        #expect(issues.contains { $0.identifier.hasPrefix("person.name.") })
        #expect(issues.contains { $0.message == "Unknown book 'Nowhere'." })
        #expect(issues.contains { $0.message.contains("Unknown difficulty") })
        #expect(issues.contains { $0.message == "Description must not be empty." })
        #expect(issues.contains { $0.identifier == "place.8" && $0.message.contains("does not exist") })
        #expect(issues.contains { $0.identifier == "place.easy" })
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
