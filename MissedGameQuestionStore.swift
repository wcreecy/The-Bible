import Foundation

/// A bounded local history of incorrect game answers, used to make future study suggestions
/// more specific without retaining the full question or answer text.
@MainActor
final class MissedGameQuestionStore {
    static let shared = MissedGameQuestionStore()

    struct Entry: Codable, Identifiable, Hashable {
        enum Game: String, Codable, CaseIterable {
            case beatTheClock
            case bibleQuiz
            case bibleTrivia
            case verseMatch
            case whoAmI
        }

        let id: UUID
        let game: Game
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
            bookNames: [String],
            chapterNumber: Int?,
            topic: String,
            questionID: String? = nil,
            date: Date
        ) {
            self.id = id
            self.game = game
            self.bookNames = bookNames
            self.chapterNumber = chapterNumber
            self.topic = topic
            self.questionID = questionID
            self.date = date
        }
    }

    /// Records that a question was answered correctly in review, so a copy of the same miss
    /// held by another device can't bring it back when the two histories are merged.
    struct Tombstone: Codable, Hashable {
        let game: Entry.Game
        let questionID: String
        let date: Date
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

    /// Bump when the trivia question set is replaced and its IDs no longer refer to the same questions.
    private static let triviaQuestionSetVersion = 3
    private static let triviaQuestionSetVersionKey = "missedGameQuestionHistory.triviaQuestionSetVersion"

    private init() {
        entries = Self.load()
        tombstones = Self.loadTombstones()
        persists = true
        prune()
        migrateTriviaQuestionSetIfNeeded()
    }

    init(entries: [Entry], tombstones: [Tombstone] = []) {
        self.entries = entries
        self.tombstones = tombstones
        persists = false
        prune()
    }

    func record(
        game: Entry.Game,
        bookNames: [String],
        chapterNumber: Int? = nil,
        topic: String,
        questionID: String? = nil,
        date: Date = Date()
    ) {
        let canonicalBooks = Array(Set(bookNames.filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        if let questionID {
            entries.removeAll { $0.game == game && $0.questionID == questionID }
        }
        entries.append(
            Entry(
                id: UUID(),
                game: game,
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
    func reviewCount(for game: Entry.Game) -> Int {
        Set(entries.compactMap { entry in
            entry.game == game ? entry.questionID : nil
        }).count
    }

    func reviewableGames(minimumQuestions: Int = 10) -> [Entry.Game] {
        Entry.Game.allCases.filter { reviewCount(for: $0) >= minimumQuestions }
    }

    func questionIDsForReview(game: Entry.Game, count: Int = 10) -> [String] {
        Array(
            Set(entries.compactMap { entry in
                entry.game == game ? entry.questionID : nil
            })
        )
        .shuffled()
        .prefix(count)
        .map(\.self)
    }

    /// A correct answer in a review round retires that question from future review rounds.
    func resolveReviewQuestion(game: Entry.Game, questionID: String, date: Date = Date()) {
        entries.removeAll { $0.game == game && $0.questionID == questionID }
        tombstones.removeAll { $0.game == game && $0.questionID == questionID }
        tombstones.append(Tombstone(game: game, questionID: questionID, date: date))
        save()
    }

    var isEmpty: Bool { entries.isEmpty && tombstones.isEmpty }

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

        var latestRetirement: [String: Date] = [:]
        for tombstone in tombstones + remote.tombstones {
            let key = Self.questionKey(tombstone.game, tombstone.questionID)
            latestRetirement[key] = max(latestRetirement[key] ?? .distantPast, tombstone.date)
        }

        // Question IDs from an older trivia set refer to different questions.
        let remoteEntries = remote.entries.map { entry -> Entry in
            guard entry.game == .bibleTrivia, entry.questionID != nil,
                  remote.triviaQuestionSetVersion < Self.triviaQuestionSetVersion else { return entry }
            return Entry(
                id: entry.id,
                game: entry.game,
                bookNames: entry.bookNames,
                chapterNumber: entry.chapterNumber,
                topic: entry.topic,
                questionID: nil,
                date: entry.date
            )
        }

        var seenIDs = Set<UUID>()
        var newestByQuestion: [String: Entry] = [:]
        var merged: [Entry] = []
        for entry in (entries + remoteEntries).sorted(by: { $0.date > $1.date }) {
            guard seenIDs.insert(entry.id).inserted else { continue }
            if let questionID = entry.questionID {
                let key = Self.questionKey(entry.game, questionID)
                if let retired = latestRetirement[key], retired >= entry.date { continue }
                guard newestByQuestion[key] == nil else { continue }
                newestByQuestion[key] = entry
            }
            merged.append(entry)
        }

        entries = merged
        tombstones = latestRetirement.compactMap { key, date in
            guard let separator = key.firstIndex(of: "|"),
                  let game = Entry.Game(rawValue: String(key[..<separator])) else { return nil }
            return Tombstone(game: game, questionID: String(key[key.index(after: separator)...]), date: date)
        }
        prune(now: now)

        let changed = Set(entries) != Set(originalEntries) || Set(tombstones) != Set(originalTombstones)
        if changed { save(publishing: false) }
        return changed
    }

    private static func questionKey(_ game: Entry.Game, _ questionID: String) -> String {
        "\(game.rawValue)|\(questionID)"
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
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: Self.triviaQuestionSetVersionKey) < Self.triviaQuestionSetVersion else { return }

        entries = entries.map { entry in
            guard entry.game == .bibleTrivia, entry.questionID != nil else { return entry }
            return Entry(
                id: entry.id,
                game: entry.game,
                bookNames: entry.bookNames,
                chapterNumber: entry.chapterNumber,
                topic: entry.topic,
                questionID: nil,
                date: entry.date
            )
        }
        save()
        defaults.set(Self.triviaQuestionSetVersion, forKey: Self.triviaQuestionSetVersionKey)
    }

    private struct ChapterKey: Hashable {
        let bookName: String
        let chapterNumber: Int
    }

    private static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return entries
    }

    private static func loadTombstones() -> [Tombstone] {
        guard let data = UserDefaults.standard.data(forKey: tombstoneStorageKey),
              let tombstones = try? JSONDecoder().decode([Tombstone].self, from: data) else {
            return []
        }
        return tombstones
    }

    /// Saves locally and, unless the change came from iCloud, asks the sync coordinator to publish it.
    private func save(publishing: Bool = true) {
        guard persists else { return }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        if let data = try? JSONEncoder().encode(tombstones) {
            UserDefaults.standard.set(data, forKey: Self.tombstoneStorageKey)
        }
        if publishing {
            iCloudSyncCoordinator.shared.pushKey(Self.storageKey)
        }
    }
}
