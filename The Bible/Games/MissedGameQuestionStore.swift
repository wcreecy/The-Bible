import Foundation

/// A bounded local history of incorrect game answers, used to make future study suggestions
/// more specific without retaining the full question or answer text.
@MainActor
final class MissedGameQuestionStore {
    static let shared = MissedGameQuestionStore(defaults: .standard)

    struct Entry: Codable, Identifiable, Hashable {
        enum Game: String, Codable, CaseIterable {
            case beatTheClock
            case bibleQuiz
            case bibleTrivia
            // Keep the stored name so synced misses and resolution tombstones retain their identity.
            case quizReverse = "verseMatch"
            case whoAmI
            case hangman
            case scramble
            /// Books placed out of order or missed in a quick round, saved by book name.
            case bookOrder
            /// WORD words not solved, saved by the word. Daily and Practice misses are reviewed
            /// together, since a word plays the same either way.
            case word

            /// The mode misses saved before modes were recorded belong to: the game's main mode.
            /// Nil for a game reviewed as one set.
            var defaultMode: String? {
                switch self {
                case .beatTheClock: "classic"
                case .whoAmI: "clueToName"
                case .bookOrder: "missingBook"
                // Verse → book misses are Standard's unless saved under Last Book Standing.
                case .bibleQuiz: "standard"
                case .quizReverse, .bibleTrivia, .hangman, .scramble, .word: nil
                }
            }

            /// The mode a saved mode's misses are reviewed in. Countdown's Survival asks the
            /// same question as Classic, and so did Rapid Fire, which it replaced, so their
            /// misses join Classic's, including ones synced from a device still on Rapid Fire.
            /// Who?'s retired Name → Clue misses are reviewed as the person's clue question.
            func reviewedMode(_ mode: String?) -> String? {
                switch (self, mode) {
                case (.beatTheClock, "survival"), (.beatTheClock, "rapidFire"): "classic"
                case (.whoAmI, "nameToClue"): "clueToName"
                default: mode
                }
            }
        }

        let id: UUID
        let game: Game
        /// The game mode the question was missed in, e.g. "firstAppearance". Nil for a game with one
        /// way to play, and for misses saved before modes were recorded.
        let mode: String?
        /// Some people and place questions relate to more than one book.
        let bookNames: [String]
        /// Present only when the question has a specific Scripture reference.
        let chapterNumber: Int?
        let topic: String
        /// A stable identifier that allows the original game to rebuild this question for review.
        let questionID: String?
        let date: Date

        init(
            id: UUID,
            game: Game,
            mode: String? = nil,
            bookNames: [String],
            chapterNumber: Int?,
            topic: String,
            questionID: String? = nil,
            date: Date
        ) {
            self.id = id
            self.game = game
            self.mode = mode
            self.bookNames = bookNames
            self.chapterNumber = chapterNumber
            self.topic = topic
            self.questionID = questionID
            self.date = date
        }

        var reviewMode: ReviewMode { ReviewMode(game: game, mode: mode) }
    }

    /// One way to replay misses: a game and the mode they were missed in. Misses are counted
    /// and replayed per mode.
    struct ReviewMode: Hashable {
        let game: Entry.Game
        /// The mode's stored name, e.g. "firstAppearance"; nil for a game with one way to play.
        let mode: String?

        /// A missing mode means the game's main mode. A game reviewed as one set has no
        /// mode, so any mode saved with its misses (such as WORD's Daily) is ignored.
        init(game: Entry.Game, mode: String? = nil) {
            self.game = game
            self.mode = game.defaultMode == nil ? nil : game.reviewedMode(mode ?? game.defaultMode)
        }
    }

    /// Records that a question was answered correctly in review, so a copy of the same miss
    /// held by another device can't bring it back when the two histories are merged.
    struct Tombstone: Codable, Hashable {
        let game: Entry.Game
        let questionID: String
        let date: Date
        /// Missing from retirements saved before modes were recorded.
        var mode: String? = nil

        var reviewMode: ReviewMode { ReviewMode(game: game, mode: mode) }
    }

    /// What one device publishes to iCloud; the other device merges it into its own history.
    struct CloudPayload: Codable, Equatable {
        var triviaQuestionSetVersion: Int
        var entries: [Entry]
        var tombstones: [Tombstone]
    }

    struct ChapterRecommendation: Hashable {
        let bookName: String
        let chapterNumber: Int
        let missedCount: Int
    }

    /// The iCloud key-value key this history is published under. Matches the local key.
    static let storageKey = "missedGameQuestionHistory"
    private static let tombstoneStorageKey = "missedGameQuestionHistory.tombstones"
    private static let maximumEntries = 500
    /// Only the newest misses are published, keeping the payload far below iCloud's 1 MB quota.
    private static let maximumCloudEntries = 300
    private static let maximumTombstones = 300
    private static let maximumCloudBytes = 120 * 1_024
    private static let retentionInterval: TimeInterval = 180 * 24 * 60 * 60

    private var entries: [Entry]
    private var tombstones: [Tombstone]
    /// False for stores built from fixed entries (tests, previews), which never touch disk or iCloud.
    private let persists: Bool
    private let defaults: UserDefaults
    /// Consumed by the sync coordinator after startup. Initializing this store never enters sync.
    private(set) var needsMigrationPublish = false

    /// Bump when the trivia question set is replaced and its IDs no longer refer to the same questions.
    private static let triviaQuestionSetVersion = 3
    private static let triviaQuestionSetVersionKey = "missedGameQuestionHistory.triviaQuestionSetVersion"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        entries = Self.load(from: defaults)
        tombstones = Self.loadTombstones(from: defaults)
        persists = true
        prune()
        migrateTriviaQuestionSetIfNeeded()
    }

    init(entries: [Entry], tombstones: [Tombstone] = []) {
        self.entries = entries
        self.tombstones = tombstones
        defaults = .standard
        persists = false
        prune()
    }

    func record(
        game: Entry.Game,
        mode: String? = nil,
        bookNames: [String],
        chapterNumber: Int? = nil,
        topic: String,
        questionID: String? = nil,
        date: Date = Date()
    ) {
        let canonicalBooks = Array(Set(bookNames.filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let reviewMode = ReviewMode(game: game, mode: mode)
        if let questionID {
            entries.removeAll { $0.reviewMode == reviewMode && $0.questionID == questionID }
        }
        entries.append(
            Entry(
                id: UUID(),
                game: game,
                mode: reviewMode.mode,
                bookNames: canonicalBooks,
                chapterNumber: chapterNumber,
                topic: topic,
                questionID: questionID,
                date: date
            )
        )
        prune()
        save()
    }

    /// The review feature works with distinct, replayable questions only. Older history entries
    /// without an identifier remain available for study recommendations but cannot be replayed.
    func reviewCount(for reviewMode: ReviewMode) -> Int {
        Set(entries.compactMap { entry in
            entry.reviewMode == reviewMode ? entry.questionID : nil
        }).count
    }

    func reviewCount(for game: Entry.Game, mode: String? = nil) -> Int {
        reviewCount(for: ReviewMode(game: game, mode: mode))
    }

    /// Whether this mode has enough misses for a review round.
    func isReviewReady(_ reviewMode: ReviewMode) -> Bool {
        reviewCount(for: reviewMode) >= Self.reviewRoundSize
    }

    /// How many missed questions a game needs before it offers a review round, and how many
    /// a round asks. The one place this number is set.
    nonisolated static let reviewRoundSize = 10

    /// The games and modes with at least `minimumQuestions` misses to replay.
    func reviewableModes(minimumQuestions: Int = reviewRoundSize) -> [ReviewMode] {
        Array(Set(entries.map(\.reviewMode))).filter { reviewCount(for: $0) >= minimumQuestions }
    }

    func questionIDsForReview(_ reviewMode: ReviewMode, count: Int = reviewRoundSize) -> [String] {
        Array(
            Set(entries.compactMap { entry in
                entry.reviewMode == reviewMode ? entry.questionID : nil
            })
        )
        .shuffled()
        .prefix(count)
        .map(\.self)
    }

    func questionIDsForReview(game: Entry.Game, mode: String? = nil, count: Int = reviewRoundSize) -> [String] {
        questionIDsForReview(ReviewMode(game: game, mode: mode), count: count)
    }

    /// Whether a miss with this identifier is still in the history for this mode.
    func containsMiss(game: Entry.Game, mode: String? = nil, questionID: String) -> Bool {
        let reviewMode = ReviewMode(game: game, mode: mode)
        return entries.contains { $0.reviewMode == reviewMode && $0.questionID == questionID }
    }

    /// A correct answer in a review round retires that question from this mode's review rounds.
    func resolveReviewQuestion(game: Entry.Game, mode: String? = nil, questionID: String, date: Date = Date()) {
        let reviewMode = ReviewMode(game: game, mode: mode)
        entries.removeAll { $0.reviewMode == reviewMode && $0.questionID == questionID }
        tombstones.removeAll { $0.reviewMode == reviewMode && $0.questionID == questionID }
        tombstones.append(Tombstone(game: game, questionID: questionID, date: date, mode: reviewMode.mode))
        save()
    }

    var isEmpty: Bool { entries.isEmpty && tombstones.isEmpty }

    /// Returns whether startup must publish a migration, clearing the request atomically.
    func takePendingMigrationPublish() -> Bool {
        defer { needsMigrationPublish = false }
        return needsMigrationPublish
    }

    /// Erases the whole history, including retirements, as part of a game data reset.
    /// Nothing is published; the reset itself tells other devices to clear theirs.
    func clearAll() {
        entries = []
        tombstones = []
        save(publishing: false)
    }

    // MARK: - iCloud sync

    /// The bounded payload published to iCloud: the newest misses plus the retirements.
    func cloudPayload() -> CloudPayload {
        var payload = CloudPayload(
            triviaQuestionSetVersion: Self.triviaQuestionSetVersion,
            entries: Array(entries.prefix(Self.maximumCloudEntries)),
            tombstones: Array(tombstones.sorted { $0.date > $1.date }.prefix(Self.maximumTombstones))
        )
        let encoder = JSONEncoder()
        while !payload.entries.isEmpty,
              ((try? encoder.encode(payload))?.count ?? 0) > Self.maximumCloudBytes {
            payload.entries.removeLast(max(1, payload.entries.count / 10))
        }
        return payload
    }

    /// Folds another device's history into this one. Returns whether anything changed.
    ///
    /// A miss survives unless the same question was answered correctly in review *after* it
    /// was recorded, so a question missed again later still comes back for review.
    @discardableResult
    func merge(_ remote: CloudPayload, now: Date = Date()) -> Bool {
        let originalEntries = entries
        let originalTombstones = tombstones

        var latestRetirement: [QuestionKey: Date] = [:]
        for tombstone in tombstones + remote.tombstones {
            let key = QuestionKey(reviewMode: tombstone.reviewMode, questionID: tombstone.questionID)
            latestRetirement[key] = max(latestRetirement[key] ?? .distantPast, tombstone.date)
        }

        // Question IDs from an older trivia set refer to different questions.
        let remoteEntries = remote.entries.map { entry -> Entry in
            guard entry.game == .bibleTrivia, entry.questionID != nil,
                  remote.triviaQuestionSetVersion < Self.triviaQuestionSetVersion else { return entry }
            return Entry(
                id: entry.id,
                game: entry.game,
                mode: entry.mode,
                bookNames: entry.bookNames,
                chapterNumber: entry.chapterNumber,
                topic: entry.topic,
                questionID: nil,
                date: entry.date
            )
        }

        var seenIDs = Set<UUID>()
        var newestByQuestion: [QuestionKey: Entry] = [:]
        var merged: [Entry] = []
        for entry in (entries + remoteEntries).sorted(by: { $0.date > $1.date }) {
            guard seenIDs.insert(entry.id).inserted else { continue }
            if let questionID = entry.questionID {
                let key = QuestionKey(reviewMode: entry.reviewMode, questionID: questionID)
                if let retired = latestRetirement[key], retired >= entry.date { continue }
                guard newestByQuestion[key] == nil else { continue }
                newestByQuestion[key] = entry
            }
            merged.append(entry)
        }

        entries = merged
        tombstones = latestRetirement.map { key, date in
            Tombstone(game: key.reviewMode.game, questionID: key.questionID, date: date, mode: key.reviewMode.mode)
        }
        prune(now: now)

        let changed = Set(entries) != Set(originalEntries) || Set(tombstones) != Set(originalTombstones)
        if changed { save(publishing: false) }
        return changed
    }

    /// One question in one mode. The same book can be missed in Tap in Order and in Missing
    /// Book; each is its own miss, retired by a right answer in that mode.
    private struct QuestionKey: Hashable {
        let reviewMode: ReviewMode
        let questionID: String
    }

    /// Returns the most frequently missed referenced chapter once it has enough misses to be actionable.
    func mostMissedChapter(minimumMisses: Int = 3) -> ChapterRecommendation? {
        var missedCounts: [ChapterKey: Int] = [:]

        for entry in entries {
            guard let chapterNumber = entry.chapterNumber else { continue }
            for bookName in entry.bookNames {
                missedCounts[ChapterKey(bookName: bookName, chapterNumber: chapterNumber), default: 0] += 1
            }
        }

        return missedCounts
            .map { ChapterRecommendation(bookName: $0.key.bookName, chapterNumber: $0.key.chapterNumber, missedCount: $0.value) }
            .filter { $0.missedCount >= minimumMisses }
            .sorted { lhs, rhs in
                if lhs.missedCount != rhs.missedCount {
                    return lhs.missedCount > rhs.missedCount
                }
                let bookOrder = lhs.bookName.localizedStandardCompare(rhs.bookName)
                if bookOrder != .orderedSame {
                    return bookOrder == .orderedAscending
                }
                return lhs.chapterNumber < rhs.chapterNumber
            }
            .first
    }

    private func prune(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.retentionInterval)
        entries = entries
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
        tombstones = Array(
            tombstones
                .filter { $0.date >= cutoff }
                .sorted { $0.date > $1.date }
                .prefix(Self.maximumTombstones)
        )
    }

    /// Misses recorded against an older trivia question set keep their book and chapter for study
    /// recommendations, but lose their question ID so review rounds can't replay a different question.
    private func migrateTriviaQuestionSetIfNeeded() {
        guard defaults.integer(forKey: Self.triviaQuestionSetVersionKey) < Self.triviaQuestionSetVersion else { return }

        entries = entries.map { entry in
            guard entry.game == .bibleTrivia, entry.questionID != nil else { return entry }
            return Entry(
                id: entry.id,
                game: entry.game,
                mode: entry.mode,
                bookNames: entry.bookNames,
                chapterNumber: entry.chapterNumber,
                topic: entry.topic,
                questionID: nil,
                date: entry.date
            )
        }
        // Never enter the sync coordinator from initialization. It consumes this flag after
        // the initial cloud download, when both singletons are fully initialized.
        save(publishing: false)
        needsMigrationPublish = true
        defaults.set(Self.triviaQuestionSetVersion, forKey: Self.triviaQuestionSetVersionKey)
    }

    private struct ChapterKey: Hashable {
        let bookName: String
        let chapterNumber: Int
    }

    private static func load(from defaults: UserDefaults) -> [Entry] {
        guard let data = defaults.data(forKey: storageKey),
              let entries = PersistedDecoding.decode([Entry].self, from: data, key: storageKey, keepingUnreadableIn: defaults) else {
            return []
        }
        return entries
    }

    private static func loadTombstones(from defaults: UserDefaults) -> [Tombstone] {
        guard let data = defaults.data(forKey: tombstoneStorageKey),
              let tombstones = PersistedDecoding.decode([Tombstone].self, from: data, key: tombstoneStorageKey, keepingUnreadableIn: defaults) else {
            return []
        }
        return tombstones
    }

    /// Saves locally and, unless the change came from iCloud, asks the sync coordinator to publish it.
    private func save(publishing: Bool = true) {
        guard persists else { return }
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.storageKey)
        }
        if let data = try? JSONEncoder().encode(tombstones) {
            defaults.set(data, forKey: Self.tombstoneStorageKey)
        }
        if publishing {
            iCloudSyncCoordinator.shared.pushKey(Self.storageKey)
        }
    }
}
