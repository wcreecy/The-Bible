import Foundation
import SwiftData
import Testing
@testable import Bible

@MainActor
struct RegressionCoverageTests {
    @Test
    func scriptureLinksRejectInvalidRangesAndParseDeepLinks() throws {
        #expect(BibleReferenceLinker.parse("John 3:17-16") == nil)

        let url = try #require(URL(string: "thebible://ref?book=John&chapter=3&start=16&end=17"))
        #expect(BibleReferenceLinker.parse(url: url) == ScriptureRef(bookName: "John", chapter: 3, startVerse: 16, endVerse: 17))
    }

    @Test
    func searchModelNormalizesQueryTokensAndTracksRecentSearches() {
        UserDefaults.standard.removeObject(forKey: "bibleRecentSearches")
        defer { UserDefaults.standard.removeObject(forKey: "bibleRecentSearches") }

        let model = BibleSearchModel()
        model.query = "  Faith, hope; LOVE  "

        #expect(model.canSearch)
        #expect(model.trimmedQuery == "Faith, hope: LOVE")
        #expect(model.tokens == ["faith", "hope", "love"])

        model.saveRecentSearch()
        model.saveRecentSearch("faith, hope: love")
        #expect(model.recentSearches == ["faith, hope: love"])
    }

    @Test
    func favoriteMatchingUsesTheCompleteVerseIdentity() {
        let john316 = Favorite(bookName: "John", chapterNumber: 3, verseNumber: 16, verseText: "For God so loved")
        let john317 = Favorite(bookName: "John", chapterNumber: 3, verseNumber: 17, verseText: "For God sent")
        let duplicate = Favorite(bookName: "John", chapterNumber: 3, verseNumber: 16, verseText: "For God so loved")

        let matches = FavoriteVerses.matching(
            [john316, john317, duplicate],
            bookName: "John",
            chapterNumber: 3,
            verseNumber: 16
        )

        #expect(matches.count == 2)
        #expect(john316.reference == "John 3:16")
    }

    @Test
    func wordSearchKeywordsAndPuzzleStayWithinTheGrid() {
        let engine = WordSearchEngine(size: 10, difficulty: .easy)
        let keywords = engine.extractKeywords(
            from: "The shepherd comforts faithful pilgrims and faithful travelers.",
            minLen: 4,
            countRange: 2...5
        )

        #expect(keywords.contains("SHEPHERD"))
        #expect(!keywords.contains("THE"))
        #expect(keywords.filter { $0 == "FAITHFUL" }.count == 1)

        let puzzle = engine.generatePuzzle(
            from: "Shepherd comforts faithful pilgrims and travelers.",
            countRange: 2...4
        )
        #expect(puzzle.grid.count == 10)
        #expect(puzzle.grid.allSatisfy { $0.count == 10 })
        #expect(puzzle.target.allSatisfy { $0.count <= 10 })
    }

    @Test
    func verseOfDayHourlyScheduleAdvancesToTheNextHour() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_123)
        let next = VOTDSchedule.nextAutoRefreshDate(
            frequency: .hourly,
            first: (hour: 6, minute: 0),
            from: now
        )
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.minute, .second], from: next)

        #expect(next > now)
        #expect(next.timeIntervalSince(now) <= 3_600)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test
    func homeLayoutBaselineIncludesEveryCardExactlyOnce() {
        let order = HomeLayoutStore.baselineOrder
        #expect(Set(order) == Set(HomeCardID.allCases))
        #expect(order.count == HomeCardID.allCases.count)
        #expect(HomeLayoutStore.baselineHidden.isSubset(of: Set(HomeCardID.allCases)))
    }

    @Test
    func cloudGameKeyCatalogIncludesEachGameAndPersistentStreaks() {
        let allKeys = iCloudSyncCoordinator.hangmanKeys
            + iCloudSyncCoordinator.beatClockKeys
            + iCloudSyncCoordinator.verseMatchKeys
            + iCloudSyncCoordinator.quizKeys
            + iCloudSyncCoordinator.bookOrderKeys
            + iCloudSyncCoordinator.whoAmIKeys
            + iCloudSyncCoordinator.wordSearchKeys

        #expect(allKeys.contains("hangmanAllTimeAnswered_easy"))
        #expect(allKeys.contains("quizAllTimeCorrect_all"))
        #expect(allKeys.contains("bookorderAllTimeBestStreak_expert"))
        #expect(iCloudSyncCoordinator.allPersistentStreakKeys.contains("wordsearchCurrentStreak"))
    }
}
