import Testing
@testable import Bible

struct ChapterBriefSummaryTests {
    /// Chapters with a brief line so far; widen as more books are written.
    private static let writtenBooks = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "John"]

    @Test
    func writtenBooksHaveOneSentenceBriefsForEveryChapter() async throws {
        let books = await BibleRepository.shared.loadAllBooks()
        for name in Self.writtenBooks {
            let book = try #require(books.first { $0.name == name })
            for chapter in 1...book.chapters.count {
                let insights = try #require(await ChapterInsightsRepository.shared.insights(forBookNamed: name, chapterNumber: chapter))
                let brief = try #require(insights.briefSummary, "\(name) \(chapter) has no brief")
                let words = brief.split(separator: " ").count
                #expect((12...30).contains(words), "\(name) \(chapter): \(words) words")
                #expect(!brief.hasPrefix("This chapter"), "\(name) \(chapter)")
                #expect(brief.hasSuffix(".") || brief.hasSuffix(".”"), "\(name) \(chapter) should end like a sentence")
            }
        }
    }

    @Test
    func chaptersWithoutABriefShowNone() async {
        let insights = await ChapterInsightsRepository.shared.insights(forBookNamed: "Joshua", chapterNumber: 1)
        #expect(insights?.briefSummary == nil)
    }
}
