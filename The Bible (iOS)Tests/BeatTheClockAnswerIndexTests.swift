import Testing
@testable import Bible

struct BeatTheClockAnswerIndexTests {
    @Test
    func phrasesCannotCrossVerseBoundaries() {
        let book = Book(
            name: "Genesis",
            chapters: [
                Chapter(
                    number: 1,
                    verses: [
                        Verse(number: 1, text: "New"),
                        Verse(number: 2, text: "Jerusalem")
                    ]
                )
            ]
        )

        let result = BeatTheClockAnswerIndex.booksMentioning(
            [(id: 1, name: "New Jerusalem")],
            in: [book]
        )

        #expect(result[1] == nil)
    }

    @Test
    func phrasesMatchWithinOneVerse() {
        let book = Book(
            name: "Genesis",
            chapters: [
                Chapter(
                    number: 1,
                    verses: [
                        Verse(number: 1, text: "New Jerusalem")
                    ]
                )
            ]
        )

        let result = BeatTheClockAnswerIndex.booksMentioning(
            [(id: 1, name: "New Jerusalem")],
            in: [book]
        )

        #expect(result[1] == ["Genesis"])
    }

    @Test
    func hyphenatedPlaceNamesMatchJoinedKJVSpelling() {
        let book = Book(
            name: "Numbers",
            chapters: [
                Chapter(
                    number: 1,
                    verses: [
                        Verse(number: 1, text: "Kadeshbarnea")
                    ]
                )
            ]
        )

        let result = BeatTheClockAnswerIndex.booksMentioning(
            [(id: 1, name: "Kadesh-barnea")],
            in: [book]
        )

        #expect(result[1] == ["Numbers"])
    }

    @Test
    @MainActor
    func referenceBookIsAlwaysAcceptedForAPlace() {
        let entry = BibleLocationChallenge(
            id: 1,
            locationName: "New Jerusalem",
            scriptureMentioned: "Revelation 21:2",
            shortDescription: "A city",
            difficulty: "Easy"
        )

        let books = BeatTheClockGameViewModel.acceptableBooks(for: entry, indexedBooks: [])

        #expect(books == ["Revelation"])
    }

    @Test
    func bookAliasesAndOrdinalSpellingsRemainCanonical() {
        let canonicalBooks = ["1 Samuel", "Revelation"]

        #expect(BibleBookNameMatcher.canonicalName(for: "First Samuel", in: canonicalBooks) == "1 Samuel")
        #expect(BibleBookNameMatcher.canonicalName(for: "Revelations", in: canonicalBooks) == "Revelation")
    }
}
