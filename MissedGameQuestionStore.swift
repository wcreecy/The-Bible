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

    private func prune(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.retentionInterval)
        entries = entries
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
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
