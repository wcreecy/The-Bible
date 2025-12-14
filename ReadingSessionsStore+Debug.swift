#if DEBUG
import Foundation

extension ReadingSessionsStore {
    // Seed 1–3 sessions per day over the last 7 days with random books/chapters and 5–25 minute durations (local time).
    func seedSampleSessionsLast7Days(calendar: Calendar = .autoupdatingCurrent) {
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent

        let bookNames: [String] = {
            let fromData = BibleData.books.map { $0.name }
            if !fromData.isEmpty { return fromData }
            return ["Genesis", "Psalms", "Proverbs", "Isaiah", "Matthew", "Mark", "Luke", "John", "Acts", "Romans"]
        }()

        let today = Date()
        for dayOffset in 0..<7 {
            guard let baseDay = cal.date(byAdding: .day, value: -dayOffset, to: cal.startOfDay(for: today)) else { continue }
            let sessionsCount = Int.random(in: 1...3)
            for _ in 0..<sessionsCount {
                let book = bookNames.randomElement() ?? "John"
                let chapter: Int? = {
                    if let b = BibleData.books.first(where: { $0.name == book }), !b.chapters.isEmpty {
                        return b.chapters.randomElement()?.number
                    }
                    return nil
                }()

                let startSeconds = Int.random(in: 8*3600...22*3600)
                let duration = Int.random(in: 5*60...25*60)
                let start = cal.date(byAdding: .second, value: startSeconds, to: baseDay) ?? baseDay
                let end = start.addingTimeInterval(TimeInterval(duration))

                let session = ReadingSessionsStore.Session(start: start, end: end, book: book, chapter: chapter)
                self.appendSession(session)
            }
        }
    }
}
#endif
