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

    struct ChapterRecommendation: Hashable {
        let bookName: String
        let chapterNumber: Int
        let missedCount: Int
    }

    private static let storageKey = "missedGameQuestionHistory"
    private static let maximumEntries = 500
    private static let retentionInterval: TimeInterval = 180 * 24 * 60 * 60

    private var entries: [Entry]

    private init() {
        entries = Self.load()
        prune()
    }

    init(entries: [Entry]) {
        self.entries = entries
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
    func resolveReviewQuestion(game: Entry.Game, questionID: String) {
        entries.removeAll { $0.game == game && $0.questionID == questionID }
        save()
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

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
