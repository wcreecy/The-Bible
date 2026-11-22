import Testing
@testable import Bible

/// Countdown's tap-to-answer boards: wrong books that are safe to offer, First Appearance's
/// earliest book, Higher or Lower's pairs, and the KJV's other spellings of names.
@MainActor
struct BeatTheClockChoicesTests {
    private let canon = BibleCanon.fallbackCanon

    private func question(
        _ label: String,
        books: Set<String>,
        unsafe: Set<String> = [],
        subject: BeatTheClockQuestion.Subject = .person
    ) -> BeatTheClockQuestion {
        BeatTheClockQuestion(
            id: "person-\(label)",
            subject: subject,
            label: label,
            clue: "",
            acceptableBooks: books,
            scriptureReference: nil,
            unsafeDecoyBooks: books.union(unsafe)
        )
    }

    @Test
    func wrongBooksAreNeverOnesThatMightMentionTheName() throws {
        // Luke calls Elijah "Elias", so it must never be offered as a wrong book.
        let elijah = question("Elijah", books: ["1 Kings", "2 Kings"], unsafe: ["Luke", "Malachi"])
        var generator = SystemRandomNumberGenerator()
        for scope in [BeatTheClockChoiceBuilder.DecoyScope.anywhere, .sameTestament, .sameSection] {
            for _ in 0..<100 {
                let choices = try #require(BeatTheClockChoiceBuilder.mentionChoices(
                    for: elijah, scope: scope, prefersBestKnownBook: false, canon: canon, using: &generator
                ))
                #expect(choices.books.count == 4)
                #expect(elijah.acceptableBooks.contains(choices.answer))
                #expect(choices.books.filter { elijah.unsafeDecoyBooks.contains($0) } == [choices.answer])
            }
        }
    }

    @Test
    func hardDrawsWrongBooksFromTheSamePartOfTheBible() throws {
        let rahab = question("Rahab", books: ["Joshua"])
        var generator = SystemRandomNumberGenerator()
        let section = try #require(QuizVerseSection.containing("Joshua"))
        for _ in 0..<50 {
            let choices = try #require(BeatTheClockChoiceBuilder.mentionChoices(
                for: rahab, scope: .sameSection, prefersBestKnownBook: false, canon: canon, using: &generator
            ))
            #expect(choices.books.allSatisfy { QuizVerseSection.containing($0) == section })
        }
    }

    @Test
    func aNameInEveryBookHasNoBoard() {
        let everywhere = question("Everyone", books: Set(canon))
        var generator = SystemRandomNumberGenerator()
        #expect(BeatTheClockChoiceBuilder.mentionChoices(
            for: everywhere, scope: .anywhere, prefersBestKnownBook: false, canon: canon, using: &generator
        ) == nil)
    }

    @Test
    func firstAppearanceIsTheEarliestBookInBibleOrder() throws {
        let aaron = question("Aaron", books: ["Hebrews", "Numbers", "Exodus", "Leviticus", "Psalms", "Acts"])
        var generator = SystemRandomNumberGenerator()
        for spread in [BeatTheClockChoiceBuilder.Spread.far, .random, .near] {
            let choices = try #require(BeatTheClockChoiceBuilder.firstAppearanceChoices(
                for: aaron, spread: spread, canon: canon, using: &generator
            ))
            #expect(choices.answer == "Exodus")
            #expect(choices.books.count == 4)
            #expect(choices.books.allSatisfy { aaron.acceptableBooks.contains($0) })
            if spread == .near {
                #expect(Set(choices.books) == ["Exodus", "Leviticus", "Numbers", "Psalms"])
            }
        }
        // Three books aren't enough for a board of four.
        #expect(BeatTheClockChoiceBuilder.firstAppearanceChoices(
            for: question("Ruth", books: ["Ruth", "Matthew", "Luke"]), spread: .random, canon: canon, using: &generator
        ) == nil)
    }

    @Test
    func higherOrLowerPairsNeverTieAndUseEachNameOnce() {
        let people = (1...12).map { question("P\($0)", books: Set(canon.prefix($0))) }
        let place = question("Place", books: Set(canon.prefix(30)), subject: .place)
        var generator = SystemRandomNumberGenerator()
        let pairs = BeatTheClockChoiceBuilder.higherOrLowerPairs(
            from: people + [place], minimumGap: 2, limit: 40, using: &generator
        )
        #expect(!pairs.isEmpty)
        let ids = pairs.flatMap { [$0.0.id, $0.1.id] }
        #expect(Set(ids).count == ids.count)
        for (first, second) in pairs {
            #expect(first.subject == second.subject)
            #expect(abs(first.acceptableBooks.count - second.acceptableBooks.count) >= 2)
        }
        // The only place has nothing to pair with.
        #expect(!ids.contains(place.id))
    }

    @Test
    func otherKJVSpellingsAreFoundInTheText() async throws {
        let books = await BibleRepository.shared.loadBooksWithoutCaching(for: .kjv)
        try #require(!books.isEmpty)
        let names = [(id: 1, name: "Elijah"), (id: 2, name: "Isaiah"), (id: 3, name: "Sidon")]
        let variants = BeatTheClockAnswerIndex.booksMentioning(BeatTheClockNameVariants.variantNames(for: names), in: books)
        // "Elias", "Esaias" and "Zidon".
        #expect(variants[1]?.contains("Luke") == true)
        #expect(variants[2]?.contains("Romans") == true)
        #expect(variants[3]?.contains("Judges") == true)
    }

    @Test
    func everyVariantBelongsToANameInTheCatalog() async {
        let people = await GameDataLoaders.loadCharactersAsync().map(\.name)
        let places = await GameDataLoaders.loadLocationChallengesAsync().map(\.locationName)
        let catalog = Set(people + places)
        #expect(Set(BeatTheClockNameVariants.spellings.keys).subtracting(catalog).isEmpty)
    }
}
