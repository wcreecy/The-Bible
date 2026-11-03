import Foundation

/// Removes redundant target ranges while preserving distinct source verses and editorial links.
@MainActor
enum ChapterCrossReferenceDeduplicator {
    static func deduplicated(
        _ insights: ChapterInsights,
        bookName: String,
        chapterNumber: Int
    ) -> ChapterInsights {
        ChapterInsights(
            overallSummary: insights.overallSummary,
            readingContext: insights.readingContext,
            keyFigures: insights.keyFigures,
            keyThemes: insights.keyThemes,
            relatedVerses: deduplicated(
                insights.relatedVerses,
                bookName: bookName,
                chapterNumber: chapterNumber
            )
        )
    }

    static func deduplicated(
        _ entries: [ChapterRelatedVerse],
        bookName: String,
        chapterNumber: Int
    ) -> [ChapterRelatedVerse] {
        let redundantIDs = redundantIDs(
            entries.map {
                Candidate(
                    id: $0.id,
                    sourceBookName: bookName,
                    sourceChapterNumber: chapterNumber,
                    sourceVerse: $0.sourceVerse,
                    relatedReference: $0.relatedReference
                )
            }
        )
        return entries.filter { !redundantIDs.contains($0.id) }
    }

    static func deduplicated(_ entries: [CrossReferenceExplorerEntry]) -> [CrossReferenceExplorerEntry] {
        let redundantIDs = redundantIDs(
            entries.map {
                Candidate(
                    id: $0.id,
                    sourceBookName: $0.bookName,
                    sourceChapterNumber: $0.chapterNumber,
                    sourceVerse: $0.sourceVerse,
                    relatedReference: $0.relatedReference
                )
            }
        )
        return entries.filter { !redundantIDs.contains($0.id) }
    }

    private struct Candidate {
        let id: Int
        let sourceBookName: String
        let sourceChapterNumber: Int
        let sourceVerse: Int
        let relatedReference: String

        var targetRange: PassageReference? {
            let references = PassageReferenceParser.parseList(
                relatedReference,
                book: sourceBookName,
                chapter: sourceChapterNumber
            )
            guard references.count == 1 else { return nil }
            return references[0]
        }
    }

    private static func redundantIDs(_ candidates: [Candidate]) -> Set<Int> {
        let parsedCandidates = candidates.map { ($0, $0.targetRange) }
        var redundantIDs = Set<Int>()

        for (candidate, target) in parsedCandidates {
            guard let target else { continue }

            for (other, otherTarget) in parsedCandidates where other.id != candidate.id {
                guard
                    candidate.sourceBookName == other.sourceBookName,
                    candidate.sourceChapterNumber == other.sourceChapterNumber,
                    candidate.sourceVerse == other.sourceVerse,
                    let otherTarget,
                    contains(otherTarget, target)
                else {
                    continue
                }

                if isStrictlyLarger(otherTarget, than: target) || other.id < candidate.id {
                    redundantIDs.insert(candidate.id)
                    break
                }
            }
        }

        return redundantIDs
    }

    private static func contains(_ outer: PassageReference, _ inner: PassageReference) -> Bool {
        guard
            outer.bookName == inner.bookName,
            let outerStartVerse = outer.startVerse,
            let outerEndVerse = outer.endVerse,
            let innerStartVerse = inner.startVerse,
            let innerEndVerse = inner.endVerse
        else {
            return false
        }

        return starts(
            chapter: outer.startChapter,
            verse: outerStartVerse,
            beforeOrAt: inner.startChapter,
            verse: innerStartVerse
        ) && ends(
            chapter: outer.endChapter,
            verse: outerEndVerse,
            afterOrAt: inner.endChapter,
            verse: innerEndVerse
        )
    }

    private static func isStrictlyLarger(_ outer: PassageReference, than inner: PassageReference) -> Bool {
        guard contains(outer, inner) else { return false }
        return outer.startChapter != inner.startChapter
            || outer.startVerse != inner.startVerse
            || outer.endChapter != inner.endChapter
            || outer.endVerse != inner.endVerse
    }

    private static func starts(
        chapter: Int,
        verse: Int,
        beforeOrAt otherChapter: Int,
        verse otherVerse: Int
    ) -> Bool {
        chapter < otherChapter || (chapter == otherChapter && verse <= otherVerse)
    }

    private static func ends(
        chapter: Int,
        verse: Int,
        afterOrAt otherChapter: Int,
        verse otherVerse: Int
    ) -> Bool {
        chapter > otherChapter || (chapter == otherChapter && verse >= otherVerse)
    }
}
