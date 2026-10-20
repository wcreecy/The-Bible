import Foundation

/// A bounded local history of incorrect game answers, used to make future study suggestions
/// more specific without retaining the full question or answer text.
@MainActor
final class MissedGameQuestionStore {
    static let shared = MissedGameQuestionStore()

    struct Entry: Codable, Identifiable, Hashable {
        enum Game: String, Codable {
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
        let date: Date
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

    func record(
        game: Entry.Game,
        bookNames: [String],
        chapterNumber: Int? = nil,
        topic: String,
        date: Date = Date()
    ) {
        let canonicalBooks = Array(Set(bookNames.filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        entries.append(
            Entry(
                id: UUID(),
                game: game,
                bookNames: canonicalBooks,
                chapterNumber: chapterNumber,
                topic: topic,
                date: date
            )
        )
        prune()
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
