import Foundation

/// Builds a reading plan for one book from a chosen length and reading style.
///
/// Days are balanced by verse count rather than chapter count, so a day of short psalms is
/// about as long as a day with Psalm 119 in it. The output only depends on its inputs.
nonisolated enum CustomPlanGenerator {
    /// A key passage of a book, such as "The Fall of Humanity: Genesis 3".
    struct Highlight: Hashable, Sendable {
        let title: String
        let reading: PlanReading
    }

    /// "Major Points" and "Skip Around" need at least this many key passages; shorter books
    /// are read in full instead.
    static let minimumHighlights = 4
    static let maximumDays = 365
    /// A day is at least about this many verses when a book is split finer than its chapters.
    static let minimumVersesPerDay = 5
    /// "Skip Around" gives its overview days no more key passages than this, when it can.
    static let maximumHighlightsPerDay = 3
    private static let passageOverheadVerses = 10

    // MARK: - Choices

    /// Whether `style` can be used for a book with these key passages.
    static func isAvailable(_ style: CustomPlanStyle, highlights: [Highlight]) -> Bool {
        !style.needsHighlights || highlights.count >= minimumHighlights
    }

    /// The lengths a plan can have, in days.
    static func dayRange(for style: CustomPlanStyle, verseCounts: [Int], highlights: [Highlight]) -> ClosedRange<Int> {
        let totalVerses = verseCounts.reduce(0, +)
        switch style {
        case .inOrder:
            let finest = max(verseCounts.count, totalVerses / minimumVersesPerDay)
            return 1...max(1, min(maximumDays, finest))
        case .majorPoints:
            return 1...max(1, min(maximumDays, highlights.count))
        case .skipAround:
            let rest = remainingChapters(verseCounts: verseCounts, highlights: highlights)
            let restVerses = rest.reduce(0) { $0 + $1.verseCount }
            let restFinest = rest.isEmpty ? 0 : max(rest.count, restVerses / minimumVersesPerDay)
            // At least one day for the key passages and one for the rest of the book.
            let fewest = rest.isEmpty ? 1 : 2
            return fewest...max(fewest, min(maximumDays, highlights.count + restFinest))
        }
    }

    /// A sensible starting length: about one chapter a day, within what the style allows.
    static func suggestedDays(for style: CustomPlanStyle, verseCounts: [Int], highlights: [Highlight]) -> Int {
        let range = dayRange(for: style, verseCounts: verseCounts, highlights: highlights)
        let suggestion: Int
        switch style {
        case .inOrder: suggestion = verseCounts.count
        case .majorPoints: suggestion = (highlights.count + 1) / 2
        case .skipAround:
            suggestion = (highlights.count + 1) / 2
                + remainingChapters(verseCounts: verseCounts, highlights: highlights).count
        }
        return min(max(suggestion, range.lowerBound), range.upperBound)
    }

    // MARK: - Building

    static func makeDays(
        bookName: String,
        verseCounts: [Int],
        highlights: [Highlight],
        style: CustomPlanStyle,
        dayCount requestedDays: Int
    ) -> [PlanDay] {
        let range = dayRange(for: style, verseCounts: verseCounts, highlights: highlights)
        let dayCount = min(max(requestedDays, range.lowerBound), range.upperBound)
        let groups: [(title: String?, readings: [PlanReading])]

        switch style {
        case .inOrder:
            let chapters = verseCounts.enumerated().map { Segment(chapter: $0.offset + 1, verseCount: $0.element) }
            groups = splitChapters(chapters, into: dayCount, bookName: bookName).map { (nil, $0) }

        case .majorPoints:
            groups = splitHighlights(highlights, into: dayCount, verseCounts: verseCounts)

        case .skipAround:
            let rest = remainingChapters(verseCounts: verseCounts, highlights: highlights)
            let (highlightDays, restDays) = skipAroundSplit(
                dayCount: dayCount,
                highlights: highlights,
                rest: rest,
                verseCounts: verseCounts
            )
            groups = splitHighlights(highlights, into: highlightDays, verseCounts: verseCounts)
                + splitChapters(rest, into: restDays, bookName: bookName).map { (nil, $0) }
        }

        return groups.enumerated().map { index, group in
            let summary = group.readings.map(\.title).joined(separator: " · ")
            return PlanDay(day: index + 1, title: group.title ?? summary, readings: group.readings)
        }
    }

    // MARK: - Key passages

    /// Turns references such as "Genesis 6:5-9:29" into readings in `bookName`, in book order.
    /// Duplicates and passages inside a longer one are dropped, so nothing is read twice.
    static func highlights(
        from references: [(title: String, reference: String)],
        bookName: String,
        verseCounts: [Int]
    ) -> [Highlight] {
        var seen = Set<PlanReading>()
        let parsed = references.compactMap { item -> Highlight? in
            guard let reading = parse(item.reference),
                  reading.book == bookName,
                  !reading.verses(verseCounts: verseCounts).isEmpty,
                  seen.insert(reading).inserted else { return nil }
            return Highlight(title: item.title, reading: reading)
        }

        func span(_ reading: PlanReading) -> (start: Int, end: Int) {
            let verses = reading.verses(verseCounts: verseCounts)
            let key = { (item: (chapter: Int, verse: Int)) in item.chapter * 1000 + item.verse }
            return (key(verses.first!), key(verses.last!))
        }

        let spans = parsed.map { span($0.reading) }
        let kept = parsed.indices.filter { index in
            // Drop a passage that sits inside another (the longer one already covers it).
            !spans.indices.contains { other in
                other != index
                    && spans[other].start <= spans[index].start
                    && spans[index].end <= spans[other].end
                    && (spans[other] != spans[index] || other < index)
            }
        }
        return kept
            .sorted { spans[$0].start < spans[$1].start }
            .map { parsed[$0] }
    }

    /// Parses "Book C", "Book C-C", "Book C:V", "Book C:V-V", or "Book C:V-C:V".
    static func parse(_ reference: String) -> PlanReading? {
        guard let regex = referencePattern,
              let match = regex.firstMatch(in: reference, range: NSRange(reference.startIndex..., in: reference)) else {
            return nil
        }
        func group(_ index: Int) -> String? {
            Range(match.range(at: index), in: reference).map { String(reference[$0]) }
        }
        guard let book = group(1), let chapter = group(2).flatMap(Int.init) else { return nil }
        let startVerse = group(3).flatMap(Int.init)
        let rangeEnd = group(4).flatMap(Int.init)
        let endVerse = group(5).flatMap(Int.init)

        switch (startVerse, rangeEnd, endVerse) {
        case let (start?, end?, nil):           // "C:V-V"
            return PlanReading(book: book, chapter: chapter, startVerse: start, endVerse: end)
        case let (start?, endChapter?, end?):   // "C:V-C:V"
            return PlanReading(book: book, chapter: chapter, endChapter: endChapter, startVerse: start, endVerse: end)
        case let (start?, nil, _):              // "C:V"
            return PlanReading(book: book, chapter: chapter, startVerse: start, endVerse: start)
        case let (nil, endChapter?, _):         // "C-C"
            return PlanReading(book: book, chapter: chapter, endChapter: endChapter)
        default:                                // "C"
            return PlanReading(book: book, chapter: chapter)
        }
    }

    private static let referencePattern = try? NSRegularExpression(
        pattern: #"^(.+?) (\d+)(?::(\d+))?(?:[-–](\d+)(?::(\d+))?)?$"#
    )

    // MARK: - Splitting

    struct Segment: Equatable {
        let chapter: Int
        let verseCount: Int
    }

    /// Chapters the key passages don't cover completely, in order.
    static func remainingChapters(verseCounts: [Int], highlights: [Highlight]) -> [Segment] {
        var covered: [Int: Set<Int>] = [:]
        for highlight in highlights {
            for item in highlight.reading.verses(verseCounts: verseCounts) {
                covered[item.chapter, default: []].insert(item.verse)
            }
        }
        return verseCounts.enumerated().compactMap { offset, count in
            let chapter = offset + 1
            return covered[chapter, default: []].count >= count ? nil : Segment(chapter: chapter, verseCount: count)
        }
    }

    /// Divides `dayCount` between the key passages and the rest of the book, by length.
    private static func skipAroundSplit(
        dayCount: Int,
        highlights: [Highlight],
        rest: [Segment],
        verseCounts: [Int]
    ) -> (highlightDays: Int, restDays: Int) {
        guard !rest.isEmpty, dayCount > 1 else { return (dayCount, 0) }
        let highlightVerses = highlights.reduce(0) { $0 + $1.reading.verses(verseCounts: verseCounts).count }
        let restVerses = rest.reduce(0) { $0 + $1.verseCount }
        let restCapacity = max(rest.count, restVerses / minimumVersesPerDay)

        let share = Double(highlightVerses) / Double(max(1, highlightVerses + restVerses))
        var highlightDays = Int((Double(dayCount) * share).rounded())
        // Key passages are short but each one is a jump to a new place, so a day holds only a few.
        let fewestForPassages = (highlights.count + maximumHighlightsPerDay - 1) / maximumHighlightsPerDay
        highlightDays = max(highlightDays, fewestForPassages)
        highlightDays = min(max(highlightDays, 1), highlights.count, dayCount - 1)
        // Give the rest no more days than it can be split into.
        highlightDays = max(highlightDays, dayCount - restCapacity)
        return (highlightDays, dayCount - highlightDays)
    }

    /// Groups key passages into `dayCount` days of similar length, keeping their order.
    private static func splitHighlights(
        _ highlights: [Highlight],
        into dayCount: Int,
        verseCounts: [Int]
    ) -> [(title: String?, readings: [PlanReading])] {
        guard dayCount > 0, !highlights.isEmpty else { return [] }
        // Each passage counts a few extra verses for finding a new place, so short passages
        // spread across days instead of piling into one.
        let weights = highlights.map { Double($0.reading.verses(verseCounts: verseCounts).count + passageOverheadVerses) }
        let cuts = balancedCuts(weights: weights, groups: min(dayCount, highlights.count), prefersCut: { _ in true })
        return ranges(from: cuts, count: highlights.count).map { range in
            let group = Array(highlights[range])
            let title = group.count == 1
                ? group[0].title
                : "\(group[0].title) and \(group.count - 1) more"
            return (title, group.map(\.reading))
        }
    }

    /// Splits chapters (which may skip some) into `dayCount` days. Whole chapters are kept
    /// together when there are enough; otherwise chapters are divided by verses, preferring
    /// to break between chapters.
    static func splitChapters(_ chapters: [Segment], into dayCount: Int, bookName: String) -> [[PlanReading]] {
        guard dayCount > 0, !chapters.isEmpty else { return [] }

        if dayCount <= chapters.count {
            let cuts = balancedCuts(
                weights: chapters.map { Double($0.verseCount) },
                groups: dayCount,
                prefersCut: { _ in true }
            )
            return ranges(from: cuts, count: chapters.count).map { range in
                readings(forChapters: Array(chapters[range]), bookName: bookName)
            }
        }

        // More days than chapters: split by verse.
        var verses: [(chapter: Int, verse: Int)] = []
        var chapterStarts = Set<Int>()
        for segment in chapters {
            chapterStarts.insert(verses.count)
            for verse in 1...max(1, segment.verseCount) {
                verses.append((segment.chapter, verse))
            }
        }
        let cuts = balancedCuts(
            weights: Array(repeating: 1, count: verses.count),
            groups: min(dayCount, verses.count),
            prefersCut: { chapterStarts.contains($0) }
        )
        let counts = Dictionary(uniqueKeysWithValues: chapters.map { ($0.chapter, $0.verseCount) })
        return ranges(from: cuts, count: verses.count).map { range in
            readings(from: Array(verses[range]), bookName: bookName, verseCounts: counts)
        }
    }

    /// Indices where each new group starts (after the first), so the groups' weights are as
    /// even as possible. `prefersCut` marks indices worth leaning toward, such as chapter starts.
    static func balancedCuts(weights: [Double], groups: Int, prefersCut: (Int) -> Bool) -> [Int] {
        let count = weights.count
        guard groups > 1, count > 1 else { return [] }
        var prefix = [0.0]
        for weight in weights { prefix.append(prefix.last! + weight) }
        let total = prefix.last!
        let typicalGroup = total / Double(groups)

        var cuts: [Int] = []
        var previous = 0
        for group in 1..<groups {
            let target = total * Double(group) / Double(groups)
            let lowest = previous + 1
            let highest = count - (groups - group)
            guard lowest <= highest else { break }
            var best = lowest
            var bestCost = Double.infinity
            for index in lowest...highest {
                var cost = abs(prefix[index] - target)
                // A break between chapters is worth being a little uneven for.
                if prefersCut(index) { cost -= typicalGroup * 0.25 }
                if cost < bestCost {
                    bestCost = cost
                    best = index
                }
            }
            cuts.append(best)
            previous = best
        }
        return cuts
    }

    private static func ranges(from cuts: [Int], count: Int) -> [Range<Int>] {
        let bounds = [0] + cuts + [count]
        return zip(bounds, bounds.dropFirst()).map { $0..<$1 }
    }

    /// Whole chapters as readings, joining runs of consecutive chapters ("Romans 1–3").
    private static func readings(forChapters chapters: [Segment], bookName: String) -> [PlanReading] {
        var result: [PlanReading] = []
        for segment in chapters {
            if let last = result.last, last.lastChapter + 1 == segment.chapter {
                result[result.count - 1] = PlanReading(book: bookName, chapter: last.chapter, endChapter: segment.chapter)
            } else {
                result.append(PlanReading(book: bookName, chapter: segment.chapter))
            }
        }
        return result
    }

    /// A run of verses as readings. Whole chapters are named without verses; a run that
    /// skips chapters becomes one reading per stretch.
    private static func readings(
        from verses: [(chapter: Int, verse: Int)],
        bookName: String,
        verseCounts: [Int: Int]
    ) -> [PlanReading] {
        guard let first = verses.first else { return [] }
        var stretches: [[(chapter: Int, verse: Int)]] = [[first]]
        for item in verses.dropFirst() {
            let previous = stretches[stretches.count - 1].last!
            let continues = (item.chapter == previous.chapter && item.verse == previous.verse + 1)
                || (item.chapter == previous.chapter + 1 && item.verse == 1
                    && previous.verse == verseCounts[previous.chapter])
            if continues {
                stretches[stretches.count - 1].append(item)
            } else {
                stretches.append([item])
            }
        }

        return stretches.map { stretch in
            let start = stretch.first!
            let end = stretch.last!
            let wholeChapters = start.verse == 1 && end.verse == verseCounts[end.chapter]
            if wholeChapters {
                return PlanReading(
                    book: bookName,
                    chapter: start.chapter,
                    endChapter: end.chapter == start.chapter ? nil : end.chapter
                )
            }
            return PlanReading(
                book: bookName,
                chapter: start.chapter,
                endChapter: end.chapter == start.chapter ? nil : end.chapter,
                startVerse: start.verse,
                endVerse: end.verse
            )
        }
    }
}
