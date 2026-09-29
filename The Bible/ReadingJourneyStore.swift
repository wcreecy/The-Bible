import Foundation

struct RecentPassage: Codable, Hashable, Identifiable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let visitedAt: Date

    var id: String {
        "\(bookName)-\(chapterNumber)-\(verseNumber)"
    }

    var reference: String {
        "\(bookName) \(chapterNumber):\(verseNumber)"
    }
}

enum ReadingJourneyStore {
    static let storageKey = "recentBiblePassages"
    private static let maximumCount = 5

    static func load(from rawValue: String = UserDefaults.standard.string(forKey: storageKey) ?? "") -> [RecentPassage] {
        guard let data = rawValue.data(using: .utf8),
              let passages = try? JSONDecoder().decode([RecentPassage].self, from: data) else {
            return []
        }
        return passages.sorted { $0.visitedAt > $1.visitedAt }
    }

    static func record(bookName: String, chapter: Int, verse: Int) {
        let passage = RecentPassage(
            bookName: bookName,
            chapterNumber: chapter,
            verseNumber: verse,
            visitedAt: Date()
        )
        var passages = load().filter { $0.id != passage.id }
        passages.insert(passage, at: 0)
        passages = Array(passages.prefix(maximumCount))

        guard let data = try? JSONEncoder().encode(passages),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}
