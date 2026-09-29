import Foundation

struct SeenVerseUpdate: Hashable, Sendable {
    let bookName: String
    let chapter: Int
    let verse: Int
    let totalVerses: Int
}

@MainActor
extension BibleStatsStore {
    // MARK: - Visited chapters (chapter-level completion)

    func loadVisitedChapters() -> Set<String> {
        if let cached = cacheVisitedChapters { return cached }
        let arr: [String] = loadJSON(key: Defaults.keyVisitedChapters, default: [])
        let set = Set(arr)
        cacheVisitedChapters = set
        return set
    }

    func saveVisitedChapters(_ set: Set<String>) {
        cacheVisitedChapters = set
        saveJSON(Array(set).sorted(), key: Defaults.keyVisitedChapters)
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyVisitedChapters)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func markVisited(bookName: String, chapterNumber: Int) {
        var set = loadVisitedChapters()
        let key = "\(bookName):\(chapterNumber)"
        guard set.insert(key).inserted else { return }
        saveVisitedChapters(set)
    }

    // MARK: - Verse-level progress

    func loadSeenVerses(bookName: String, chapter: Int) -> Set<Int> {
        ensureSeenVerseCacheLoaded()
        return cacheSeenVersesByChapter?["\(bookName):\(chapter)"] ?? []
    }

    func saveSeenVerses(_ verses: [Int], bookName: String, chapter: Int) {
        ensureSeenVerseCacheLoaded()
        var map = cacheSeenVersesByChapter ?? [:]
        map["\(bookName):\(chapter)"] = Set(verses)
        persistSeenVerseMap(map)
    }

    func markVerseSeen(bookName: String, chapter: Int, verse: Int, totalVerses: Int) {
        markVersesSeen([
            SeenVerseUpdate(
                bookName: bookName,
                chapter: chapter,
                verse: verse,
                totalVerses: totalVerses
            )
        ])
    }

    /// Applies a group of verse updates with one seen-verse persistence and sync operation.
    func markVersesSeen(_ updates: Set<SeenVerseUpdate>, date: Date = Date()) {
        let validUpdates = updates.filter {
            $0.chapter > 0 &&
            $0.totalVerses > 0 &&
            (1...$0.totalVerses).contains($0.verse)
        }
        guard !validUpdates.isEmpty else { return }

        ensureSeenVerseCacheLoaded()
        var seenMap = cacheSeenVersesByChapter ?? [:]
        var totalsByChapter: [String: Int] = [:]
        var changed = false

        for update in validUpdates {
            let key = "\(update.bookName):\(update.chapter)"
            totalsByChapter[key] = max(totalsByChapter[key, default: 0], update.totalVerses)
            changed = seenMap[key, default: []].insert(update.verse).inserted || changed
        }

        guard changed else { return }
        persistSeenVerseMap(seenMap, notify: false)

        var visited = loadVisitedChapters()
        var completionDates = loadChapterCompletionDates()
        var visitedChanged = false
        var datesChanged = false

        for (key, totalVerses) in totalsByChapter {
            guard totalVerses > 0 else { continue }
            let validSeenCount = seenMap[key, default: []].filter {
                (1...totalVerses).contains($0)
            }.count
            guard validSeenCount >= totalVerses else { continue }

            visitedChanged = visited.insert(key).inserted || visitedChanged
            if completionDates[key] == nil {
                completionDates[key] = date
                datesChanged = true
            }
        }

        if visitedChanged {
            cacheVisitedChapters = visited
            saveJSON(Array(visited).sorted(), key: Defaults.keyVisitedChapters)
            iCloudSyncCoordinator.shared.pushKey(Defaults.keyVisitedChapters)
        }
        if datesChanged {
            cacheChapterCompletionDates = completionDates
            saveJSON(completionDates, key: Defaults.keyChapterCompletionDates)
            iCloudSyncCoordinator.shared.pushKey(Defaults.keyChapterCompletionDates)
        }

        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func isChapterComplete(bookName: String, chapter: Int, totalVerses: Int) -> Bool {
        guard totalVerses > 0 else { return false }
        let seen = loadSeenVerses(bookName: bookName, chapter: chapter)
        return seen.filter { (1...totalVerses).contains($0) }.count >= totalVerses
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
        var calendar = calendar
        calendar.timeZone = TimeZone.autoupdatingCurrent
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return map.filter { _, completionDate in
            let components = calendar.dateComponents([.year, .month], from: completionDate)
            return components.year == year && components.month == month
        }
    }

    private func ensureSeenVerseCacheLoaded() {
        guard cacheSeenVersesByChapter == nil else { return }
        let raw: [String: [Int]] = loadJSON(key: Defaults.keySeenVersesByChapter, default: [:])
        cacheSeenVersesByChapter = raw.mapValues(Set.init)
    }

    private func persistSeenVerseMap(_ map: SeenMap, notify: Bool = true) {
        cacheSeenVersesByChapter = map
        let raw = map.mapValues { Array($0).sorted() }
        saveJSON(raw, key: Defaults.keySeenVersesByChapter)
        iCloudSyncCoordinator.shared.pushKey(Defaults.keySeenVersesByChapter)
        if notify {
            NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        }
    }
}
