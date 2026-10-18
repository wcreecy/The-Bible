import Foundation

/// Stores a small, local history of recent misses so the games can bring them back
/// into practice without changing a player's chosen difficulty or category settings.
@MainActor
enum AdaptivePracticeStore {
    private static let storageKey = "adaptivePracticeHistory"
    private static let maximumEntries = 40
    private static let retentionInterval: TimeInterval = 30 * 24 * 60 * 60

    private struct History: Codable {
        var verses: [VerseMiss] = []
        var books: [BookMiss] = []
    }

    private struct VerseMiss: Codable, Hashable {
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        var lastMissedAt: Date

        var key: String {
            "\(bookName)|\(chapterNumber)|\(verseNumber)"
        }
    }

    private struct BookMiss: Codable, Hashable {
        let bookName: String
        var lastMissedAt: Date
    }

    private static func loadHistory() -> History {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let history = try? JSONDecoder().decode(History.self, from: data) else {
            return History()
        }

        let cutoff = Date().addingTimeInterval(-retentionInterval)
        return History(
            verses: history.verses.filter { $0.lastMissedAt >= cutoff },
            books: history.books.filter { $0.lastMissedAt >= cutoff }
        )
    }

    private static func save(_ history: History) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func recordVerseMiss(
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int
    ) {
        var history = loadHistory()
        let newMiss = VerseMiss(
            bookName: bookName,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber,
            lastMissedAt: .now
        )
        history.verses.removeAll { $0.key == newMiss.key }
        history.verses.insert(newMiss, at: 0)
        history.verses = Array(history.verses.prefix(maximumEntries))
        save(history)
    }

    static func recordBookMisses(_ bookNames: some Sequence<String>) {
        var history = loadHistory()
        var seen: Set<String> = []

        for bookName in bookNames where seen.insert(bookName).inserted {
            history.books.removeAll { $0.bookName == bookName }
            history.books.insert(BookMiss(bookName: bookName, lastMissedAt: .now), at: 0)
        }

        history.books = Array(history.books.prefix(maximumEntries))
        save(history)
    }

    static func recentVerseKeys() -> Set<String> {
        Set(loadHistory().verses.map(\.key))
    }

    static func recentBookNames(in availableBooks: [String]) -> [String] {
        let available = Set(availableBooks)
        return loadHistory().books
            .filter { available.contains($0.bookName) }
            .map(\.bookName)
    }
}
