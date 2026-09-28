import Foundation

@MainActor
extension BibleStatsStore {
    // MARK: - Per-day per-book totals (for time-windowed top books)

    func loadDailyTotalsByBook() -> [String: [String: Int]] {
        if let cached = cacheDailyTotalsByBook { return cached }
        let dict: [String: [String: Int]] = loadJSON(key: Defaults.keyDailyTotalsByBook, default: [:])
        cacheDailyTotalsByBook = dict
        return dict
    }

    func saveDailyTotalsByBook(_ dict: [String: [String: Int]]) {
        cacheDailyTotalsByBook = dict
        saveJSON(dict, key: Defaults.keyDailyTotalsByBook)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyDailyTotalsByBook)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func addToToday(bookName: String, seconds: Int, calendar: Calendar = .autoupdatingCurrent) {
        guard seconds > 0, !bookName.isEmpty else { return }
        var dict = loadDailyTotalsByBook()
        let today = Self.isoDateString(Date(), calendar: calendar)
        var perBook = dict[today] ?? [:]
        perBook[bookName, default: 0] += seconds
        dict[today] = perBook
        saveDailyTotalsByBook(dict)
    }

    // MARK: - OT/NT split

    // Splits a per-book totals map into Old Testament vs New Testament sums.
    // Uses the canonical order in BibleData.books, with "Matthew" as the first NT book.
    func splitOTNT(totals: [String: Int]) -> (ot: Int, nt: Int) {
        let books = BibleData.books
        // Build name -> index map
        let indexMap: [String: Int] = Dictionary(uniqueKeysWithValues: books.enumerated().map { ($1.name, $0) })
        let matthewIndex: Int? = indexMap["Matthew"]
        if let mIdx = matthewIndex {
            var ot = 0
            var nt = 0
            for (book, seconds) in totals {
                let idx = indexMap[book] ?? Int.max
                if idx < mIdx { ot += max(0, seconds) } else { nt += max(0, seconds) }
            }
            return (ot, nt)
        } else {
            // Fallback: use Canon sets
            var ot = 0
            var nt = 0
            for (book, seconds) in totals {
                if Canon.old.contains(book) {
                    ot += max(0, seconds)
                } else if Canon.new.contains(book) {
                    nt += max(0, seconds)
                } else {
                    // Unknown book name: ignore (or choose a default bucket)
                }
            }
            return (ot, nt)
        }
    }
}
