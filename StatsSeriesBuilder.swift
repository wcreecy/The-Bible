import Foundation
import SwiftUI

struct StatsSeriesBuilder {
    enum Aggregation { case daily, weekly, monthly, yearly }

    // Average length of sessions (seconds) with pre-filtering done by caller if needed.
    static func averageSessionLength(sessions: [ReadingSessionsStore.Session], minSessionSeconds: Int) -> Int {
        let filtered = sessions.filter { Int(max(0, $0.end.timeIntervalSince($0.start))) >= minSessionSeconds }
        guard !filtered.isEmpty else { return 0 }
        let total = filtered.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        return total / filtered.count
    }

    enum Genre: String, CaseIterable, Identifiable {
        case Law = "Law"
        case History = "History"
        case Poetry = "Poetry"
        case MajorProphets = "Major Prophets"
        case MinorProphets = "Minor Prophets"
        case Gospels = "Gospels"
        case Acts = "Acts"
        case Epistles = "Epistles"
        case Apocalypse = "Apocalypse"

        var id: String { rawValue }
    }

    static func genreForBook(_ book: String) -> Genre {
        switch book {
        case "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy":
            return .Law
        case "Joshua", "Judges", "Ruth",
             "1 Samuel", "2 Samuel",
             "1 Kings", "2 Kings",
             "1 Chronicles", "2 Chronicles",
             "Ezra", "Nehemiah", "Esther":
            return .History
        case "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon":
            return .Poetry
        case "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel":
            return .MajorProphets
        case "Hosea", "Joel", "Amos", "Obadiah", "Jonah",
             "Micah", "Nahum", "Habakkuk", "Zephaniah",
             "Haggai", "Zechariah", "Malachi":
            return .MinorProphets
        case "Matthew", "Mark", "Luke", "John":
            return .Gospels
        case "Acts":
            return .Acts
        case "Romans",
             "1 Corinthians", "2 Corinthians",
             "Galatians", "Ephesians", "Philippians", "Colossians",
             "1 Thessalonians", "2 Thessalonians",
             "1 Timothy", "2 Timothy",
             "Titus", "Philemon",
             "Hebrews", "James",
             "1 Peter", "2 Peter",
             "1 John", "2 John", "3 John",
             "Jude":
            return .Epistles
        case "Revelation":
            return .Apocalypse
        default:
            return .History
        }
    }

    static func computeGenreTotals(from perBook: [String: Int]) -> [(genre: String, seconds: Int)] {
        var buckets: [Genre: Int] = [:]
        for (book, seconds) in perBook {
            let g = genreForBook(book)
            buckets[g, default: 0] += max(0, seconds)
        }
        let order: [Genre] = [.Law, .History, .Poetry, .MajorProphets, .MinorProphets, .Gospels, .Acts, .Epistles, .Apocalypse]
        return order.map { g in (genre: g.rawValue, seconds: buckets[g, default: 0]) }
    }
}
