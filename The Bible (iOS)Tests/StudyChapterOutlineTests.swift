import Foundation
import Testing
@testable import Bible

@MainActor
struct StudyChapterOutlineTests {
    @Test
    func firstWholeChapterReadsEachPassageFormat() {
        #expect(StudyChapterOutline.firstWholeChapter(of: "Genesis 12-50", bookName: "Genesis") == 12)
        #expect(StudyChapterOutline.firstWholeChapter(of: "1 Corinthians 15", bookName: "1 Corinthians") == 15)
        #expect(StudyChapterOutline.firstWholeChapter(of: "1 Peter 1:1-2:10", bookName: "1 Peter") == 1)
        #expect(StudyChapterOutline.firstWholeChapter(of: "Isaiah 40–48", bookName: "Isaiah") == 40)

        // Starting mid-chapter, the first whole chapter is the next one.
        #expect(StudyChapterOutline.firstWholeChapter(of: "1 Peter 2:11-4:19", bookName: "1 Peter") == 3)

        // Scattered passages, another book, or text that isn't a reference.
        #expect(StudyChapterOutline.firstWholeChapter(of: "Daniel 3; 6", bookName: "Daniel") == nil)
        #expect(StudyChapterOutline.firstWholeChapter(of: "John 1-3", bookName: "1 John") == nil)
        #expect(StudyChapterOutline.firstWholeChapter(of: "Genesis", bookName: "Genesis") == nil)
    }

    @Test
    func gapsJoinTheSectionBeforeThem() {
        let sections = StudyChapterOutline.sections(
            bookName: "Genesis",
            movements: [
                ("Creation and the Fall", ["Genesis 1-3"]),
                ("The Flood and Noah", ["Genesis 6-9"]),
                ("The Patriarchs and Joseph", ["Genesis 12-50"])
            ],
            chapterCount: 50
        )
        #expect(sections.map(\.chapters) == [1...5, 6...11, 12...50])
        #expect(sections.map(\.title) == ["Creation and the Fall", "The Flood and Noah", "The Patriarchs and Joseph"])
    }

    @Test
    func aChapterBelongsToTheSectionItBeginsIn() {
        let sections = StudyChapterOutline.sections(
            bookName: "Jonah",
            movements: [
                ("Jonah Flees", ["Jonah 1"]),
                ("Jonah Rescued and Sent Again", ["Jonah 2-3:2"]),
                ("Nineveh Repents", ["Jonah 3:3-4:11"])
            ],
            chapterCount: 4
        )
        #expect(sections.map(\.chapters) == [1...1, 2...3, 4...4])
    }

    @Test
    func thematicOrSingleChapterSectionsAreNotGrouped() {
        // Psalms' sections gather psalms from across the book.
        #expect(StudyChapterOutline.sections(
            bookName: "Psalms",
            movements: [
                ("Lament and Trust", ["Psalms 3; 13; 22; 42-43"]),
                ("Kingship and Messianic Hope", ["Psalms 2; 45; 72; 110"]),
                ("Praise and Thanksgiving", ["Psalms 103; 107; 145-150"])
            ],
            chapterCount: 150
        ).isEmpty)

        // Sections out of order don't outline the book.
        #expect(StudyChapterOutline.sections(
            bookName: "Example",
            movements: [("Later", ["Example 5-9"]), ("Earlier", ["Example 1-4"])],
            chapterCount: 9
        ).isEmpty)

        // A one-chapter book's sections all fall within its only chapter.
        #expect(StudyChapterOutline.sections(
            bookName: "Obadiah",
            movements: [
                ("Edom's Pride Exposed", ["Obadiah 1:1-9"]),
                ("Violence against Judah Condemned", ["Obadiah 1:10-14"]),
                ("Day of the LORD", ["Obadiah 1:15-21"])
            ],
            chapterCount: 1
        ).isEmpty)
    }

    /// Every book's sections, as shipped, either cover each chapter exactly once in order
    /// or are left ungrouped.
    @Test
    func shippedSectionsCoverEveryChapterOnce() async throws {
        let url = try #require(Bundle.main.url(forResource: "kjv", withExtension: "json"))
        let books = try BibleData.decodeBooks(from: Data(contentsOf: url))
        #expect(books.count == 66)

        var groupedBooks: Set<String> = []
        for book in books {
            let movements = await BibleBookOverviewRepository.shared.movements(forBookNamed: book.name)
            let sections = StudyChapterOutline.sections(
                bookName: book.name,
                movements: movements.map { ($0.title, $0.keyPassages) },
                chapterCount: book.chapters.count
            )
            guard !sections.isEmpty else { continue }
            groupedBooks.insert(book.name)
            #expect(sections.flatMap { Array($0.chapters) } == Array(1...book.chapters.count), "\(book.name)")
        }

        #expect(groupedBooks.contains("Genesis"))
        #expect(groupedBooks.contains("Revelation"))
        #expect(!groupedBooks.contains("Psalms"))
        #expect(!groupedBooks.contains("Daniel"))
    }

    @Test
    func everyChapterHasThemesToPreview() async throws {
        let themes = await ChapterInsightsRepository.shared.themeNames(forBookNamed: "Psalms")
        #expect(themes.count == 150)
        #expect(themes[1]?.first == "Delight in God's word")
    }
}
