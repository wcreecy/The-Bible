import Foundation

/// How the Study page lists a book's chapters.
enum ChapterListLayout: String, CaseIterable, Identifiable {
    /// A compact grid of chapter numbers.
    case simple
    /// A row per chapter with its key themes, grouped under the book's sections.
    case detailed

    static let storageKey = "chapterListLayout"

    var id: Self { self }

    var title: String {
        switch self {
        case .simple: "Chapter Grid"
        case .detailed: "By Theme"
        }
    }

    var helperText: String {
        switch self {
        case .simple:
            "Quickly jump to a chapter number."
        case .detailed:
            "Browse chapters by key themes and book sections."
        }
    }

    var systemImage: String {
        switch self {
        case .simple: "square.grid.3x3"
        case .detailed: "list.bullet.rectangle"
        }
    }
}

/// A run of chapters under one of a book's sections, such as "Creation and the Fall".
struct StudyChapterSection: Identifiable, Equatable {
    let title: String
    let chapters: ClosedRange<Int>

    var id: Int { chapters.lowerBound }
}

enum StudyChapterOutline {
    /// Groups a book's chapters under its sections, or returns nothing when the sections
    /// don't form an outline of the book.
    ///
    /// Some books' sections are themes drawn from across the book (Psalms' "Lament and
    /// Trust" is Psalms 3, 13, 22, and 42–43) rather than consecutive passages, so grouping
    /// only happens when every section is one passage and each starts after the one before.
    /// A chapter belongs to the section it begins in, so a section starting mid-chapter
    /// (1 Peter 2:11) starts with the next chapter. Chapters between sections join the
    /// section before them, and a book that ends up with one section isn't grouped.
    static func sections(
        bookName: String,
        movements: [(title: String, passages: [String])],
        chapterCount: Int
    ) -> [StudyChapterSection] {
        guard chapterCount > 0 else { return [] }

        var starts: [(title: String, chapter: Int)] = []
        for movement in movements {
            guard movement.passages.count == 1,
                  let chapter = firstWholeChapter(of: movement.passages[0], bookName: bookName) else {
                return []
            }
            // A section that starts past the last chapter covers no whole chapter.
            guard chapter <= chapterCount else { continue }
            if let previous = starts.last, chapter <= previous.chapter { return [] }
            starts.append((movement.title, chapter))
        }
        guard starts.count > 1 else { return [] }

        return starts.indices.map { index in
            let first = index == 0 ? 1 : starts[index].chapter
            let last = index + 1 < starts.count ? starts[index + 1].chapter - 1 : chapterCount
            return StudyChapterSection(title: starts[index].title, chapters: first...last)
        }
    }

    /// The first chapter a passage covers from its first verse: "Genesis 12-50" is 12,
    /// "1 Peter 2:11-4:19" is 3. Nil for a passage that isn't one continuous range in the book.
    static func firstWholeChapter(of passage: String, bookName: String) -> Int? {
        let trimmed = passage.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(bookName + " ") else { return nil }
        let range = trimmed.dropFirst(bookName.count + 1)
        guard !range.contains(";"), !range.contains(",") else { return nil }

        let start = range.split(maxSplits: 1, whereSeparator: { $0 == "-" || $0 == "–" }).first ?? range
        let parts = start.split(separator: ":")
        guard let chapter = parts.first.flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }) else {
            return nil
        }
        guard parts.count > 1 else { return chapter }
        guard let verse = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return verse <= 1 ? chapter : chapter + 1
    }
}
