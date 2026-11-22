import Foundation
import Testing
@testable import Bible

/// Review rounds count, replay and retire misses per game mode: the same question missed in
/// two modes is two misses, and a game is ready once any one mode has a full round.
///
/// Misses go to stores that never touch disk or iCloud, and any defaults a game writes
/// (stats, streaks) are put back when each test ends.
@Suite(.serialized)
@MainActor
struct ReviewRoundModeTests {
    private typealias ReviewMode = MissedGameQuestionStore.ReviewMode

    private func withRestoredDefaults(_ body: () async throws -> Void) async rethrows {
        await StandardDefaultsLock.lock()
        defer { StandardDefaultsLock.unlock() }
        let before = UserDefaults.standard.dictionaryRepresentation()
        defer {
            let defaults = UserDefaults.standard
            let after = defaults.dictionaryRepresentation()
            for key in Set(before.keys).union(after.keys) {
                let old = before[key].map { $0 as AnyObject }
                let new = after[key].map { $0 as AnyObject }
                guard old?.isEqual(new) != true else { continue }
                if let old { defaults.set(old, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        try await body()
    }

    private func entry(
        _ game: MissedGameQuestionStore.Entry.Game,
        mode: String? = nil,
        _ questionID: String,
        date: Date = Date()
    ) -> MissedGameQuestionStore.Entry {
        MissedGameQuestionStore.Entry(
            id: UUID(), game: game, mode: mode, bookNames: [], chapterNumber: nil,
            topic: "Test", questionID: questionID, date: date
        )
    }

    // MARK: - Counting and retiring per mode

    @Test func theSameQuestionMissedInTwoModesIsTwoMisses() {
        let store = MissedGameQuestionStore(entries: [])
        store.record(game: .bookOrder, mode: "tapInOrder", bookNames: ["Ruth"], topic: "Book order", questionID: "Ruth")
        store.record(game: .bookOrder, mode: "beforeAfter", bookNames: ["Ruth"], topic: "Book order", questionID: "Ruth")
        // Missed again in the same mode, it's still one miss.
        store.record(game: .bookOrder, mode: "tapInOrder", bookNames: ["Ruth"], topic: "Book order", questionID: "Ruth")

        #expect(store.reviewCount(for: .bookOrder, mode: "tapInOrder") == 1)
        #expect(store.reviewCount(for: .bookOrder, mode: "beforeAfter") == 1)
        #expect(store.reviewCount(for: .bookOrder, mode: "missingBook") == 0)
    }

    @Test func aRightAnswerRetiresTheQuestionOnlyInItsMode() {
        let store = MissedGameQuestionStore(entries: [
            entry(.beatTheClock, mode: "classic", "person-1"),
            entry(.beatTheClock, mode: "rapidFire", "person-1")
        ])
        store.resolveReviewQuestion(game: .beatTheClock, mode: "rapidFire", questionID: "person-1")

        #expect(!store.containsMiss(game: .beatTheClock, mode: "rapidFire", questionID: "person-1"))
        #expect(store.containsMiss(game: .beatTheClock, mode: "classic", questionID: "person-1"))
    }

    @Test func missesSavedBeforeModesCountTowardTheGamesMainMode() {
        let store = MissedGameQuestionStore(entries: [
            entry(.beatTheClock, "person-1"),
            entry(.bookOrder, "Ruth"),
            entry(.whoAmI, "who-1"),
            entry(.bibleTrivia, "42")
        ])

        #expect(store.reviewCount(for: .beatTheClock, mode: "classic") == 1)
        #expect(store.reviewCount(for: .bookOrder, mode: "missingBook") == 1)
        #expect(store.reviewCount(for: .whoAmI, mode: "clueToName") == 1)
        #expect(store.reviewCount(for: .bibleTrivia) == 1)
        // And a right answer in that mode retires them.
        store.resolveReviewQuestion(game: .beatTheClock, mode: "classic", questionID: "person-1")
        #expect(store.reviewCount(for: .beatTheClock) == 0)
    }

    @Test func eachModeUnlocksItsOwnReview() {
        let store = MissedGameQuestionStore(entries:
            (0..<10).map { entry(.beatTheClock, mode: "rapidFire", "person-\($0)") }
                + (0..<4).map { entry(.beatTheClock, mode: "classic", "place-\($0)") }
        )

        #expect(store.isReviewReady(ReviewMode(game: .beatTheClock, mode: "rapidFire")))
        #expect(!store.isReviewReady(ReviewMode(game: .beatTheClock, mode: "classic")))
        #expect(store.reviewableModes() == [ReviewMode(game: .beatTheClock, mode: "rapidFire")])
        #expect(Set(store.questionIDsForReview(ReviewMode(game: .beatTheClock, mode: "rapidFire"))).allSatisfy { $0.hasPrefix("person-") })
    }

    // MARK: - Sync

    @Test func syncKeepsModesApartAndRetiresPerMode() {
        let missed = Date(timeIntervalSince1970: 1_000)
        let phone = MissedGameQuestionStore(entries: [entry(.whoAmI, mode: "clueToName", "who-1", date: missed)])
        let tablet = MissedGameQuestionStore(entries: [entry(.whoAmI, mode: "nameToClue", "who-1", date: missed)])
        tablet.resolveReviewQuestion(game: .whoAmI, mode: "nameToClue", questionID: "who-1", date: missed.addingTimeInterval(60))
        tablet.record(game: .whoAmI, mode: "nameToClue", bookNames: [], topic: "Test", questionID: "who-2", date: missed)

        phone.merge(tablet.cloudPayload(), now: missed.addingTimeInterval(120))

        // The tablet's retirement in Name → Clue leaves the phone's Clue → Name miss alone.
        #expect(phone.containsMiss(game: .whoAmI, mode: "clueToName", questionID: "who-1"))
        #expect(!phone.containsMiss(game: .whoAmI, mode: "nameToClue", questionID: "who-1"))
        #expect(phone.containsMiss(game: .whoAmI, mode: "nameToClue", questionID: "who-2"))
    }

    @Test func historyFromBeforeModesStillLoads() throws {
        let json = """
        {"triviaQuestionSetVersion": 3,
         "entries": [{"id": "\(UUID().uuidString)", "game": "beatTheClock", "bookNames": [],
                      "topic": "Bible people", "questionID": "person-1", "date": 800000000}],
         "tombstones": [{"game": "bookOrder", "questionID": "Ruth", "date": 800000000}]}
        """
        let payload = try JSONDecoder().decode(MissedGameQuestionStore.CloudPayload.self, from: Data(json.utf8))
        #expect(payload.entries.first?.mode == nil)
        #expect(payload.entries.first?.reviewMode == ReviewMode(game: .beatTheClock, mode: "classic"))
        #expect(payload.tombstones.first?.reviewMode == ReviewMode(game: .bookOrder, mode: "missingBook"))
    }

    // MARK: - Review cards

    @Test func aGameIsReadyOnceAnyModeHasAFullRound() {
        let store = MissedGameQuestionStore(entries:
            (0..<10).map { entry(.bookOrder, mode: "whichSection", "Book \($0)") }
                + (0..<3).map { entry(.bookOrder, mode: "tapInOrder", "Book \($0)") }
        )
        let progress = ReviewRoundProgress.all(store: store)
        let bookOrder = try? #require(progress.first { $0.game == .bookOrder })
        let quiz = try? #require(progress.first { $0.game == .quiz })

        #expect(bookOrder?.isReady == true)
        #expect(quiz?.isReady == false)
        let counts = Dictionary(uniqueKeysWithValues: (bookOrder?.modeCounts ?? []).map { ($0.mode.reviewMode.mode ?? "", $0.count) })
        #expect(counts == ["tapInOrder": 3, "beforeAfter": 0, "missingBook": 0, "whichSection": 10, "classic": 0])
        // Every game but Crossword and Word Search is on the list, with each of its modes.
        #expect(progress.map(\.game) == ReviewGame.allCases)
        #expect(quiz?.modeCounts.count == 2)
    }

    // MARK: - Book Order puzzles

    @Test func aTapInOrderReviewIsTheMissedBooksAndClearsThoseTappedRight() async {
        let missed = ["Revelation", "Ruth", "Genesis", "Jude"]
        let store = MissedGameQuestionStore(entries: missed.map { entry(.bookOrder, mode: "tapInOrder", $0) })
        await withRestoredDefaults {
            let game = BookOrderGameViewModel(reviewBooks: missed, reviewMode: .tapInOrder, missedQuestions: store)
            game.preparePuzzle(.tapInOrder)
            #expect(!game.hasSavedPuzzle)
            game.startGame()
            #expect(game.correctOrder == ["Genesis", "Ruth", "Jude", "Revelation"])
            #expect(Set(game.currentItems) == Set(missed))

            // Ruth tapped too early stays missed; the rest are cleared.
            game.tap("Ruth", elapsedSeconds: 1)
            for book in game.correctOrder {
                game.tap(book, elapsedSeconds: 5)
            }
            #expect(game.showResult)
            #expect(store.containsMiss(game: .bookOrder, mode: "tapInOrder", questionID: "Ruth"))
            #expect(store.reviewCount(for: .bookOrder, mode: "tapInOrder") == 1)
            // A review puzzle never sets a best time.
            #expect(!game.isNewBestTime)
        }
    }

    // MARK: - WORD

    @Test func aWordReviewPlaysEachMissedWordAndClearsTheSolvedOnes() async {
        let store = MissedGameQuestionStore(entries: [
            entry(.word, mode: "Daily", "GRACE"),
            entry(.word, mode: "Daily", "FAITH")
        ])
        await withRestoredDefaults {
            let game = WordleGameViewModel(reviewWords: ["GRACE", "FAITH"], reviewMode: .daily, missedQuestions: store)
            game.startNewRound(practice: true)
            let first = game.target
            #expect(["GRACE", "FAITH"].contains(first))
            #expect(!game.isDailyRound)
            #expect(game.reviewWordNumber == 1)
            game.endRound(win: true)
            #expect(!store.containsMiss(game: .word, mode: "Daily", questionID: first))

            #expect(game.hasNextReviewWord)
            game.startNewRound(practice: true)
            let second = game.target
            #expect(second != first)
            game.endRound(win: false)
            #expect(store.containsMiss(game: .word, mode: "Daily", questionID: second))
            #expect(!game.hasNextReviewWord)
            #expect(game.reviewSolvedCount == 1)
        }
    }

    @Test func aLostPracticeWordIsSavedForReviewUnderPractice() async {
        let store = MissedGameQuestionStore(entries: [])
        await withRestoredDefaults {
            let game = WordleGameViewModel(missedQuestions: store)
            game.started = true
            game.target = "GRACE"
            game.endRound(win: false)
            #expect(store.containsMiss(game: .word, mode: "Practice", questionID: "GRACE"))
            #expect(store.reviewCount(for: .word, mode: "Daily") == 0)
        }
    }
}
