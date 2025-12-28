#if DEBUG
import Foundation

extension BibleStatsStore {
    // Debug helpers for chapter/verse completion against a default book (John preferred)
    private func defaultBook() -> Book? {
        if let john = BibleData.books.first(where: { $0.name == "John" }) { return john }
        return BibleData.books.first
    }

    func markFirstThreeChaptersCompleteDefaultBook() {
        guard let book = defaultBook() else { return }
        let chapters = book.chapters.prefix(3)
        for chap in chapters {
            let verses = chap.verses.map { $0.number }
            self.saveSeenVerses(verses, bookName: book.name, chapter: chap.number)
        }
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
    }

    func clearChapterOneForDefaultBook() {
        guard let book = defaultBook() else { return }
        self.saveSeenVerses([], bookName: book.name, chapter: 1)
        var visited = self.loadVisitedChapters()
        visited.remove("\(book.name):1")
        self.saveVisitedChapters(visited)
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
    }

    func verseCoverageSummaryForDefaultBook(firstNChapters: Int = 5) -> String {
        guard let book = defaultBook() else { return "" }
        var lines: [String] = []
        for chap in book.chapters.prefix(firstNChapters) {
            let total = chap.verses.count
            let seen = self.loadSeenVerses(bookName: book.name, chapter: chap.number)
            let pct = total > 0 ? Int(round(Double(seen.count) / Double(total) * 100.0)) : 0
            lines.append("Chapter \(chap.number): \(seen.count)/\(total) (\(pct)%)")
        }
        return lines.joined(separator: "\n")
    }
}
#endif
