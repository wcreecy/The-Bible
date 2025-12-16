import Foundation

@MainActor
extension BibleStatsStore {
    // MARK: - Visited chapters (chapter-level completion)

    func loadVisitedChapters() -> Set<String> {
        if let cached = cacheVisitedChapters { return cached }
        // Stored as [String] JSON; convert to Set
        let arr: [String] = loadJSON(key: Defaults.keyVisitedChapters, default: [])
        let set = Set(arr)
        cacheVisitedChapters = set
        return set
    }

    func saveVisitedChapters(_ set: Set<String>) {
        cacheVisitedChapters = set
        let arr = Array(set).sorted()
        saveJSON(arr, key: Defaults.keyVisitedChapters)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyVisitedChapters)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func markVisited(bookName: String, chapterNumber: Int) {
        var set = loadVisitedChapters()
        let key = "\(bookName):\(chapterNumber)"
        // Only write and notify if this is a new insertion to avoid notification loops
        if set.contains(key) {
            return
        }
        set.insert(key)
        saveVisitedChapters(set)
    }

    // MARK: - Verse-level progress (seen verses + chapter completion dates)

    func loadSeenVerses(bookName: String, chapter: Int) -> Set<Int> {
        if let cached = cacheSeenVersesByChapter {
            return cached["\(bookName):\(chapter)"] ?? []
        }
        // Load [String: [Int]] from JSON and convert to Set<Int>
        let raw: [String: [Int]] = loadJSON(key: Defaults.keySeenVersesByChapter, default: [:])
        var map: SeenMap = [:]
        for (k, arr) in raw {
            map[k] = Set(arr)
        }
        cacheSeenVersesByChapter = map
        return map["\(bookName):\(chapter)"] ?? []
    }

    func saveSeenVerses(_ verses: [Int], bookName: String, chapter: Int) {
        var map = cacheSeenVersesByChapter ?? [:]
        map["\(bookName):\(chapter)"] = Set(verses)
        cacheSeenVersesByChapter = map
        // Persist as [String: [Int]] sorted
        var raw: [String: [Int]] = [:]
        for (k, set) in map {
            raw[k] = Array(set).sorted()
        }
        saveJSON(raw, key: Defaults.keySeenVersesByChapter)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keySeenVersesByChapter)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // Convenience to mark one verse and optionally set completion date when full
    func markVerseSeen(bookName: String, chapter: Int, verse: Int, totalVerses: Int) {
        var seen = loadSeenVerses(bookName: bookName, chapter: chapter)
        if !seen.contains(verse) {
            seen.insert(verse)
            saveSeenVerses(Array(seen), bookName: bookName, chapter: chapter)
            if totalVerses > 0, seen.count >= totalVerses {
                markVisited(bookName: bookName, chapterNumber: chapter)
                setChapterCompletionDateIfNeeded(bookName: String(bookName), chapter: chapter, date: Date())
            }
        }
    }

    func isChapterComplete(bookName: String, chapter: Int, totalVerses: Int) -> Bool {
        let seen = loadSeenVerses(bookName: bookName, chapter: chapter)
        return totalVerses > 0 && seen.count >= totalVerses
    }

    private func setChapterCompletionDateIfNeeded(bookName: String, chapter: Int, date: Date) {
        var map = loadChapterCompletionDates()
        let key = "\(bookName):\(chapter)"
        if map[key] == nil {
            map[key] = date
            saveChapterCompletionDates(map)
        }
    }

    func loadChapterCompletionDates() -> [String: Date] {
        if let cached = cacheChapterCompletionDates { return cached }
        let dict: [String: Date] = loadJSON(key: Defaults.keyChapterCompletionDates, default: [:])
        cacheChapterCompletionDates = dict
        return dict
    }

    func saveChapterCompletionDates(_ dict: [String: Date]) {
        cacheChapterCompletionDates = dict
        saveJSON(dict, key: Defaults.keyChapterCompletionDates)
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyChapterCompletionDates)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func chapterCompletions(inMonth date: Date, calendar: Calendar = .autoupdatingCurrent) -> [String: Date] {
        let map = loadChapterCompletionDates()
        var cal = calendar
        // Use local time zone for month grouping
        cal.timeZone = TimeZone.autoupdatingCurrent
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        return map.filter { (_, d) in
            let comps = cal.dateComponents([.year, .month], from: d)
            return comps.year == year && comps.month == month
        }
    }
}
