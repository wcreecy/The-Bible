import Foundation
import Testing
@testable import Bible

// Temporary: exports every Scripture connection the app shows, for auditing.
@MainActor
struct TemporaryConnectionAudit {
    @Test
    func writeAuditFile() async throws {
        let entries = await CrossReferenceExplorerEntry.loadAll()
        let books = await BibleRepository.shared.loadAllBooks(for: .kjv)
        let canon = Dictionary(uniqueKeysWithValues: BibleCanon.canonicalOrder().enumerated().map { ($0.element, $0.offset) })

        let sorted = entries.sorted {
            (canon[$0.bookName] ?? .max, $0.chapterNumber, $0.sourceVerse, $0.relatedReference)
                < (canon[$1.bookName] ?? .max, $1.chapterNumber, $1.sourceVerse, $1.relatedReference)
        }

        func field(_ value: String) -> String {
            "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }

        func text(_ reference: PassageReference) -> String {
            guard let book = books.first(where: { $0.name == reference.bookName }) else { return "" }
            return book.chapters
                .filter { $0.number >= reference.startChapter && $0.number <= reference.endChapter }
                .flatMap { chapter in
                    chapter.verses.filter { verse in
                        if verse.isOmitted { return false }
                        guard let start = reference.startVerse else { return true }
                        if chapter.number == reference.startChapter, verse.number < start { return false }
                        if let end = reference.endVerse, chapter.number == reference.endChapter, verse.number > end { return false }
                        return true
                    }
                }
                .map { "\($0.number) \($0.text)" }
                .joined(separator: " ")
        }

        var lines = [[
            "Connection ID", "Source Reference", "Related Reference",
            "Has Written Explanation", "Relationship Shown in App", "Connection Type",
            "Source Text (KJV)", "Related Text (KJV)",
            "Catalog Book", "Catalog Chapter", "Catalog Source Verse",
            "Catalog Target Book", "Catalog Target Chapter", "Catalog Target Verse"
        ].map(field).joined(separator: ",")]

        var written = 0
        for entry in sorted {
            guard let target = PassageReferenceParser.parseList(
                entry.relatedReference,
                book: entry.bookName,
                chapter: entry.chapterNumber
            ).first else { continue }
            let source = entry.sourcePassage
            let hasWritten = entry.writtenExplanation != nil
            if hasWritten { written += 1 }
            lines.append([
                String(entry.id), entry.sourceReference, entry.relatedReference,
                hasWritten ? "Yes" : "No",
                entry.relationshipDescription,
                entry.connectionType?.title.description ?? "",
                text(source), text(target),
                entry.bookName, String(entry.chapterNumber), String(entry.sourceVerse),
                target.bookName, String(target.startChapter), String(target.startVerse ?? 0)
            ].map(field).joined(separator: ","))
        }

        let url = URL(fileURLWithPath: "/Users/williamcreecy/Desktop/Scripture Connections Audit.csv")
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        print("AUDIT total=\(sorted.count) written=\(written) missing=\(sorted.count - written)")
    }
}
