#if DEBUG
import Foundation

@MainActor
extension BibleStatsStore {

    // Seeds 31 days of reading data across sessions, daily totals, per-book totals,
    // last read, and reading progress (seen verses + a few completed chapters).
    // - Populates:
    //   • Home Bible Stats card: Today, This Week (rolling 7), This Month, All-Time, Last Session, Last Read
    //   • Stats page: Reading Progress card, Reading Time card (daily series), OT vs NT, Genre Distribution
    //   • Already covered: Average Session Length and Top Books This Month
    func seedRandomReadingStatsPast31Days(calendar: Calendar = .autoupdatingCurrent) {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent

        let books = BibleData.books
        guard !books.isEmpty else { return }

        // Load existing maps (so we append rather than clobber)
        var perBookAllTime: [String: Int] = loadJSON(key: Defaults.keyTotals, default: [:])
        var dailyTotals: [String: Int] = loadJSON(key: Defaults.keyDailyTotals, default: [:])
        var dailyByBook: [String: [String: Int]] = loadJSON(key: Defaults.keyDailyTotalsByBook, default: [:])

        // Generate 1–3 sessions per day for last 31 days, random OT/NT mix
        let today = Date()
        var lastSession: ReadingSessionsStore.Session? = nil

        for dayOffset in 0..<31 {
            guard let baseDay = cal.date(byAdding: .day, value: -dayOffset, to: cal.startOfDay(for: today)) else { continue }
            let sessionsCount = Int.random(in: 1...3)

            for _ in 0..<sessionsCount {
                // Pick a random book and chapter
                let book = books.randomElement()!
                let bookName = book.name
                let chapter = book.chapters.randomElement()
                let chapterNumber = chapter?.number

                // Pick a start time within the day and a 5–25 minute duration
                let startSeconds = Int.random(in: 8*3600...22*3600)
                let duration = Int.random(in: 5*60...25*60)
                let start = cal.date(byAdding: .second, value: startSeconds, to: baseDay) ?? baseDay
                let end = start.addingTimeInterval(TimeInterval(duration))
                let dayKey = Self.isoDateString(end, calendar: cal)

                // Append to ReadingSessionsStore (drives last session + avg length UI)
                let s = ReadingSessionsStore.Session(start: start, end: end, book: bookName, chapter: chapterNumber)
                ReadingSessionsStore.shared.appendSession(s)
                if lastSession == nil || s.end > (lastSession?.end ?? .distantPast) {
                    lastSession = s
                }

                // Update all-time per-book totals
                perBookAllTime[bookName, default: 0] += duration

                // Update daily totals (overall)
                dailyTotals[dayKey, default: 0] += duration

                // Update daily totals by book
                var perBook = dailyByBook[dayKey] ?? [:]
                perBook[bookName, default: 0] += duration
                dailyByBook[dayKey] = perBook
            }
        }

        // Persist updated maps
        saveJSON(perBookAllTime, key: Defaults.keyTotals)
        saveJSON(dailyTotals, key: Defaults.keyDailyTotals)
        saveJSON(dailyByBook, key: Defaults.keyDailyTotalsByBook)

        // Seed a plausible "Last Read" near now using the last session's book/chapter
        if let last = lastSession {
            let chap = last.chapter ?? {
                if let b = books.first(where: { $0.name == last.book }) {
                    return b.chapters.first?.number ?? 1
                }
                return 1
            }()
            saveLastRead(bookName: last.book, chapterNumber: chap, date: last.end)
        } else {
            // Fallback: random last read today if no sessions were created
            if let b = books.randomElement(), let c = b.chapters.randomElement() {
                saveLastRead(bookName: b.name, chapterNumber: c.number, date: today)
            }
        }

        // Seed reading progress:
        // - Mark a handful of chapters as fully seen (completes them today, contributing to this month’s completed count)
        // - Mark scattered verses in a few other chapters to show partial progress and boost overall verse coverage
        do {
            // Complete 2–3 chapters in two random books
            let completeBooks = Array(books.shuffled().prefix(2))
            for book in completeBooks {
                let chaptersToComplete = Array(book.chapters.prefix(min(3, book.chapters.count)))
                for chap in chaptersToComplete {
                    let totalVerses = chap.verses.count
                    guard totalVerses > 0 else { continue }
                    for v in 1...totalVerses {
                        // markVerseSeen will set chapter completion date once all verses are seen
                        self.markVerseSeen(bookName: book.name, chapter: chap.number, verse: v, totalVerses: totalVerses)
                    }
                }
            }

            // Partially mark verses in a few other random chapters
            let partialTargets = 4
            var picked: [(String, Int, Int)] = [] // (book, chapter, totalVerses)
            outer: for b in books.shuffled() {
                for c in b.chapters.shuffled() {
                    let totalVerses = c.verses.count
                    guard totalVerses > 0 else { continue }
                    picked.append((b.name, c.number, totalVerses))
                    if picked.count >= partialTargets { break outer }
                }
            }
            for (bookName, chapNum, totalVerses) in picked {
                let marks = Int.random(in: 3...max(3, totalVerses / 2))
                let versesToSee = Set((1...totalVerses).shuffled().prefix(marks))
                for v in versesToSee {
                    self.markVerseSeen(bookName: bookName, chapter: chapNum, verse: v, totalVerses: totalVerses)
                }
            }
        }

        // Push changed keys to iCloud KVS (so other devices/widgets see it), and notify UI
        let kvs = iCloudSyncCoordinator.shared
        kvs.pushKey(Defaults.keyTotals)
        kvs.pushKey(Defaults.keyDailyTotals)
        kvs.pushKey(Defaults.keyDailyTotalsByBook)
        kvs.pushKey(Defaults.keyLastRead)
        kvs.pushKey(Defaults.keySeenVersesByChapter)
        kvs.pushKey(Defaults.keyChapterCompletionDates)

        // Invalidate caches and notify observers so Home/Stats refresh immediately
        resetCaches()
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }
}
#endif
