import Testing
@testable import Bible

struct ChapterBriefSummaryTests {
    /// Every book now has a brief line for each chapter.
    private static let writtenBooks = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation"]

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
}
