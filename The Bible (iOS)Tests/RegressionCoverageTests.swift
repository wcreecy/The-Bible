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
    func notePassageReferencesCanonicalizeBookAbbreviations() {
        #expect(BibleReferenceLinker.canonicalReference(for: "ex 3:1") == "Exodus 3:1")
        #expect(BibleReferenceLinker.canonicalReference(for: "jn 3:16-17") == "John 3:16-17")
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
    func verseOfDayScheduleIsMirroredToTheWidgetAppGroup() throws {
        let keys = [
            "votdRefreshFrequency",
            "votdRefresh1Hour",
            "votdRefresh1Minute",
            "votdRefresh2Hour",
            "votdRefresh2Minute"
        ]
        let standardDefaults = UserDefaults.standard
        let sharedDefaults = try #require(UserDefaults(suiteName: "group.bible.app"))
        let originalStandardValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, standardDefaults.object(forKey: $0)) })
        let originalSharedValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, sharedDefaults.object(forKey: $0)) })
        defer {
            for key in keys {
                if let value = originalStandardValues[key] {
                    standardDefaults.set(value, forKey: key)
                } else {
                    standardDefaults.removeObject(forKey: key)
                }
                if let value = originalSharedValues[key] {
                    sharedDefaults.set(value, forKey: key)
                } else {
                    sharedDefaults.removeObject(forKey: key)
                }
            }
        }

        standardDefaults.set("daily", forKey: "votdRefreshFrequency")
        standardDefaults.set(9, forKey: "votdRefresh1Hour")
        standardDefaults.set(30, forKey: "votdRefresh1Minute")
        standardDefaults.set(21, forKey: "votdRefresh2Hour")
        standardDefaults.set(45, forKey: "votdRefresh2Minute")

        let viewModel = VerseOfDayViewModel()
        viewModel.refreshScheduleChanged()

        #expect(sharedDefaults.string(forKey: "votdRefreshFrequency") == "daily")
        #expect(sharedDefaults.integer(forKey: "votdRefresh1Hour") == 9)
        #expect(sharedDefaults.integer(forKey: "votdRefresh1Minute") == 30)
        #expect(sharedDefaults.integer(forKey: "votdRefresh2Hour") == 21)
        #expect(sharedDefaults.integer(forKey: "votdRefresh2Minute") == 45)
    }

    @Test
    func todayChallengesRequireReplacementOnTheNextLocalDay() throws {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let todayKey = GameStats.localDayKey(for: today)

        #expect(!TodayChallengeStore.needsNewChallenges(snapshotDayKey: todayKey, on: today))
        #expect(TodayChallengeStore.needsNewChallenges(snapshotDayKey: todayKey, on: tomorrow))
    }

    @Test
    func savedVerseChallengesAreSystemTracked() {
        #expect(TodayChallengeStore.kind(forReflectionTaskTitle: "Add a verse to your favorites") == .favoriteVerse)
        #expect(TodayChallengeStore.kind(forReflectionTaskTitle: "Highlight a verse to study later") == .highlightVerse)
        #expect(TodayChallengeStore.kind(forReflectionTaskTitle: "Bookmark a verse") == .reflection)
        #expect(TodayChallengeStore.kind(forReflectionTaskTitle: "Add a verse to your bookmarks") == .reflection)
    }

    @Test
    func monthlySavedVersePromptsHaveDistinctDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15)))

        let favoriteDay = TodayChallengeStore.monthlySystemTaskDay(
            for: "Add a verse to your favorites",
            on: date
        )
        let highlightDay = TodayChallengeStore.monthlySystemTaskDay(
            for: "Highlight a verse to study later",
            on: date
        )

        #expect((1...31).contains(favoriteDay))
        #expect((1...31).contains(highlightDay))
        #expect(favoriteDay != highlightDay)
    }

    @Test
    func homeLayoutBaselineIncludesEveryCardExactlyOnce() {
        let order = HomeLayoutStore.baselineOrder
        #expect(Set(order) == Set(HomeCardID.allCases))
        #expect(order.count == HomeCardID.allCases.count)
        #expect(order.contains(.savedVerses))
        #expect(!HomeLayoutStore.baselineHidden.contains(.savedVerses))
        #expect(HomeLayoutStore.baselineHidden.isSubset(of: Set(HomeCardID.allCases)))
    }

    @Test
    func customTagsAreExtractedFromBodiesAndNormalizeTagSearches() {
        let tags = NoteCustomTags.tags(in: "#Faith and #grace, then #FAITH. C# is not a tag.")

        #expect(tags == ["faith", "grace"])

        let rangeText = "#test tags #faith, more"
        let parsedTags = NoteCustomTags.ranges(in: rangeText).map { String(rangeText[$0]) }
        #expect(parsedTags == ["#test", "#faith"])

        #expect(NoteCustomTags.normalizedSearchTag(from: "#Faith") == "faith")
        #expect(NoteCustomTags.normalizedSearchTag(from: "faith") == nil)
        #expect(NoteCustomTags.normalizedSearchTag(from: "#faith today") == nil)
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

@MainActor
struct NotesTabTests {
    private func verseNote(
        _ book: String, _ chapter: Int, _ verse: Int, through end: Int = 0,
        title: String = "", content: String = "", highlight: String = "",
        favorite: Bool = false, updated: TimeInterval = 0
    ) -> VerseNote {
        let note = VerseNote()
        note.bookName = book
        note.chapterNumber = chapter
        note.verseNumber = verse
        note.endVerseNumber = end
        note.title = title
        note.content = content
        note.highlightColor = highlight
        note.isFavorite = favorite
        note.categoryRawValue = NoteCategory.scripture.rawValue
        note.updatedAt = Date(timeIntervalSince1970: updated)
        return note
    }

    private func userNote(
        title: String, content: String = "", category: NoteCategory = .personal,
        passage: String = "", favorite: Bool = false, updated: TimeInterval = 0
    ) -> UserNote {
        let note = UserNote()
        note.title = title
        note.content = content
        note.categoryRawValue = category.rawValue
        note.passageReference = passage
        note.isFavorite = favorite
        note.updatedAt = Date(timeIntervalSince1970: updated)
        return note
    }

    private func library(
        _ verseNotes: [VerseNote], _ userNotes: [UserNote],
        filters: NotesFilters = NotesFilters(), sort: NotesTabSort = .modified, ascending: Bool = false
    ) -> NotesLibrary {
        NotesLibrary(scriptureNotes: verseNotes, userNotes: userNotes, filters: filters, sort: sort, ascending: ascending)
    }

    @Test
    func libraryFiltersSortsAndPutsFavoritesFirst() {
        let highlight = verseNote("John", 3, 16, highlight: "yellow", updated: 30)
        let written = verseNote("Romans", 8, 28, title: "Hope", content: "All things #hope", highlight: "blue", updated: 20)
        let sermon = userNote(title: "Sunday", content: "#hope #faith", category: .sermon, updated: 10)
        let favorite = userNote(title: "Psalm", content: "#faith", favorite: true, updated: 0)
        let notes = ([highlight, written], [sermon, favorite])

        // A verse highlighted without a note belongs to Saved Verses, not Notes.
        let all = library(notes.0, notes.1)
        #expect(all.visibleItems.map(\.title) == ["Psalm", "Hope", "Sunday"])
        #expect(all.allItems.count == 3)
        #expect(all.tags == [.init(tag: "faith", count: 2), .init(tag: "hope", count: 2)])

        var filters = NotesFilters()
        filters.category = .sermon
        #expect(library(notes.0, notes.1, filters: filters).visibleItems.map(\.title) == ["Sunday"])

        filters = NotesFilters(tag: "hope")
        #expect(library(notes.0, notes.1, filters: filters, sort: .title, ascending: true).visibleItems.map(\.title) == ["Hope", "Sunday"])

        filters = NotesFilters(category: .sermon, tag: "hope")
        let summary = library(notes.0, notes.1, filters: filters).summaryTitle
        #expect(summary.contains("#hope"))
        #expect(summary.hasSuffix("1"))
        #expect(filters.isActive)
        #expect(!NotesFilters().isActive)
    }

    @Test
    func searchFindsNotesByFullReferenceAbbreviationAndTag() async {
        _ = await BibleRepository.shared.loadAllBooks()

        let titled = verseNote("John", 3, 14, through: 18, title: "God so loved")
        let other = verseNote("John", 4, 1, title: "Samaritan woman")
        let passage = userNote(title: "Nicodemus", passage: "John 3:1-21")
        let tagged = userNote(title: "Tagged", content: "#john316 notes")
        let notes = ([titled, other], [passage, tagged])

        for query in ["John 3:16", "Jn 3:16", "john 3:16"] {
            let found = library(notes.0, notes.1, filters: NotesFilters(search: query)).visibleItems.map(\.title)
            #expect(Set(found) == ["God so loved", "Nicodemus"], "query: \(query)")
        }
        #expect(library(notes.0, notes.1, filters: NotesFilters(search: "#john316")).visibleItems.map(\.title) == ["Tagged"])
        #expect(library(notes.0, notes.1, filters: NotesFilters(search: "samaritan")).visibleItems.map(\.title) == ["Samaritan woman"])
    }

    @Test
    func verseRangesCoverEachVerseAndFormatReferences() {
        let single = verseNote("John", 3, 16)
        let range = verseNote("John", 3, 16, through: 18)
        #expect(single.reference == "John 3:16")
        #expect(range.reference == "John 3:16–18")
        #expect(range.covers(bookName: "John", chapterNumber: 3, verseNumber: 17))
        #expect(!range.covers(bookName: "John", chapterNumber: 3, verseNumber: 19))
        #expect(!single.covers(bookName: "John", chapterNumber: 3, verseNumber: 17))
    }

    @Test
    func tagsRenameMergeAndRemoveKeepingTheWord() {
        let text = "#Prayer list: #prayer, #prayers and C#prayer"
        #expect(NoteCustomTags.renaming("prayer", to: "praise", in: text) == "#praise list: #praise, #prayers and C#prayer")
        #expect(NoteCustomTags.renaming("prayer", to: nil, in: text) == "Prayer list: prayer, #prayers and C#prayer")

        var formatted = AttributedString("Bold #hope here")
        formatted.inlinePresentationIntent = .stronglyEmphasized
        let renamed = NoteCustomTags.renaming("hope", to: "faith", in: formatted)
        #expect(String(renamed.characters) == "Bold #faith here")
        #expect(renamed.runs.allSatisfy { $0.inlinePresentationIntent == .stronglyEmphasized })

        let note = userNote(title: "#hope", content: "Keep #hope")
        note.formattedContent = try? JSONEncoder().encode(AttributedString("Keep #hope"))
        let untouched = userNote(title: "Other", content: "nothing")
        let changed = NoteTagEditor.rename("hope", to: "faith", verseNotes: [], userNotes: [note, untouched])
        #expect(changed == 1)
        #expect(note.title == "#faith")
        #expect(note.content == "Keep #faith")
        #expect(String(NoteFormattedContent.decode(note.formattedContent, fallback: "").characters) == "Keep #faith")

        #expect(NoteCustomTags.normalizedTag(" #Grace ") == "grace")
        #expect(NoteCustomTags.normalizedTag("two words") == nil)
    }

    @Test
    func partialTagFindsTheTagBeingTyped() {
        let text = "Pray #gra and C#x"
        let partial = NoteCustomTags.partialTag(in: text, endingAt: 9)
        #expect(partial?.prefix == "gra")
        #expect(partial.map { String(text[$0.range]) } == "#gra")
        #expect(NoteCustomTags.partialTag(in: "Pray #", endingAt: 6)?.prefix == "")
        #expect(NoteCustomTags.partialTag(in: text, endingAt: 8) == nil)   // caret mid-tag
        #expect(NoteCustomTags.partialTag(in: text, endingAt: 17) == nil)  // "C#x" isn't a tag
        #expect(NoteCustomTags.partialTag(in: text, endingAt: 4) == nil)
    }

    @Test
    func listMarkersParseAndContinue() {
        let bullet = NoteListMarker.parse("    • Item")
        #expect(bullet?.indent == "    ")
        #expect(bullet?.marker.kind == .bullet("•"))
        #expect(bullet?.content == "Item")

        let numbered = NoteListMarker.parse("2) Next")
        #expect(numbered?.marker.next.text == "3)")
        #expect(NoteListMarker.parse("2024. was a year") == nil)
        #expect(NoteListMarker.parse("Plain text") == nil)

        let nested = NoteListMarker(kind: .bullet("•")).adjusted(toIndent: "    ", after: [])
        #expect(nested.kind == .bullet("◦"))
        let continued = NoteListMarker(kind: .number(1, punctuation: ".")).adjusted(toIndent: "", after: ["1. One", "2. Two"])
        #expect(continued.text == "3.")
    }

    @Test
    func draftsRoundTripThroughStorage() throws {
        let defaults = try #require(UserDefaults(suiteName: "NotesTabTests.drafts"))
        defer { defaults.removePersistentDomain(forName: "NotesTabTests.drafts") }

        let key = NoteDraftStore.key(forVerse: "John", chapter: 3, verse: 16)
        #expect(key == NoteDraftStore.key(forVerse: "John", chapter: 3, verse: 16))
        #expect(NoteDraftStore.key(forUserNote: nil).hasSuffix("user.new"))

        var draft = NoteDraft(
            title: "Draft",
            body: try JSONEncoder().encode(AttributedString("Body #tag")),
            category: NoteCategory.sermon.rawValue,
            endVerseNumber: 18,
            sermonSpeaker: "Speaker",
            sermonDate: Date(timeIntervalSince1970: 100)
        )
        // Drafts built from the same edits compare equal until one is stamped when saved.
        #expect(draft == draft)
        draft.savedAt = Date(timeIntervalSince1970: 200)
        NoteDraftStore.save(draft, for: key, defaults: defaults)

        let loaded = try #require(NoteDraftStore.load(key, defaults: defaults))
        #expect(loaded == draft)
        #expect(String(loaded.bodyText.characters) == "Body #tag")

        NoteDraftStore.clear(key, defaults: defaults)
        #expect(NoteDraftStore.load(key, defaults: defaults) == nil)
    }

    @Test
    func bibleTriviaProgressMergesQuestionCompletionAcrossDevices() throws {
        let local = [
            "easy": BibleTriviaDifficultyProgress(completedQuestionIDs: [1, 2]),
            "normal": BibleTriviaDifficultyProgress(completedQuestionIDs: [10])
        ]
        let remote = [
            "easy": BibleTriviaDifficultyProgress(completedQuestionIDs: [2, 3]),
            "hard": BibleTriviaDifficultyProgress(completedQuestionIDs: [100])
        ]

        let localData = try JSONEncoder().encode(local)
        let remoteData = try JSONEncoder().encode(remote)
        let mergedData = try #require(BibleTriviaProgressStore.mergedData(local: localData, remote: remoteData))
        let merged = try JSONDecoder().decode([String: BibleTriviaDifficultyProgress].self, from: mergedData)

        #expect(merged["easy"]?.completedQuestionIDs == Set([1, 2, 3]))
        #expect(merged["normal"]?.completedQuestionIDs == Set([10]))
        #expect(merged["hard"]?.completedQuestionIDs == Set([100]))
    }

    @Test
    func exportIncludesEveryNoteNewestFirst() {
        let older = userNote(title: "Older", content: "First", passage: "Romans 8:28", updated: 0)
        let newer = verseNote("John", 3, 16, title: "Newer", content: "Second", updated: 100)
        newer.verseText = "For God so loved the world"
        let items = [NotesListItem.user(older), .scripture(newer)]

        let markdown = NotesMarkdownExporter.markdown(for: items)
        let newerIndex = try? #require(markdown.range(of: "## Newer"))
        let olderIndex = try? #require(markdown.range(of: "## Older"))
        #expect(markdown.hasPrefix("# Bible Notes"))
        #expect(markdown.contains("> For God so loved the world"))
        #expect(markdown.contains("Romans 8:28"))
        if let newerIndex, let olderIndex {
            #expect(newerIndex.lowerBound < olderIndex.lowerBound)
        }
    }
}
