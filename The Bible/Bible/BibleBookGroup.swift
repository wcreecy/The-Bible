import Foundation

/// The kinds of book the Bible's book lists are grouped by, in canonical order. One place
/// decides which group a book is in, so the Books list, the iPad sidebar, and the reader's
/// book picker always agree.
enum BibleBookGroup: CaseIterable, Identifiable {
    case law
    case history
    case wisdomAndPoetry
    case majorProphets
    case minorProphets
    case gospelsAndActs
    case letters
    case revelation

    var id: Self { self }

    var title: String {
        switch self {
        case .law: "Law"
        case .history: "History"
        case .wisdomAndPoetry: "Wisdom & Poetry"
        case .majorProphets: "Major Prophets"
        case .minorProphets: "Minor Prophets"
        case .gospelsAndActs: "Gospels & Acts"
        case .letters: "Letters"
        case .revelation: "Apocalyptic"
        }
    }

    var testament: Testament {
        switch self {
        case .law, .history, .wisdomAndPoetry, .majorProphets, .minorProphets: .old
        case .gospelsAndActs, .letters, .revelation: .new
        }
    }

    /// The group a book belongs to. Acts joins the Gospels, since it continues Luke.
    static func group(for bookName: String) -> BibleBookGroup {
        switch bookName {
        case "Acts": return .gospelsAndActs
        case "Revelation": return .revelation
        default: break
        }
        switch BibleStudyMetadata.studyFilter(for: bookName) {
        case .law: return .law
        case .history: return .history
        case .poetry: return .wisdomAndPoetry
        case .majorProphets: return .majorProphets
        case .minorProphets: return .minorProphets
        case .gospels: return .gospelsAndActs
        default: return .letters
        }
    }

    /// The books in each group that has any, in the order given.
    static func grouping(_ books: [Book]) -> [(group: BibleBookGroup, books: [Book])] {
        allCases.compactMap { group in
            let members = books.filter { Self.group(for: $0.name) == group }
            return members.isEmpty ? nil : (group, members)
        }
    }
}
