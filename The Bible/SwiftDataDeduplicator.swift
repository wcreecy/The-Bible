import Foundation
import SwiftData

/// Removes duplicate per-verse records created when the same verse is favorited or
/// highlighted on two devices before CloudKit syncs. CloudKit-backed SwiftData stores
/// cannot use unique constraints, so duplicates are resolved after they arrive.
@MainActor
enum SwiftDataDeduplicator {
    private struct VerseKey: Hashable {
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
    }

    static func run(in context: ModelContext) {
        let removedFavorites = dedupeFavorites(in: context)
        let removedNotes = dedupeVerseNotes(in: context)
        guard removedFavorites || removedNotes else { return }
        try? context.save()
    }

    /// Keeps the earliest favorite for each verse.
    private static func dedupeFavorites(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Favorite>(
            sortBy: [SortDescriptor(\Favorite.createdAt, order: .forward)]
        )
        guard let favorites = try? context.fetch(descriptor), favorites.count > 1 else { return false }

        var seen = Set<VerseKey>()
        var removed = false
        for favorite in favorites {
            let key = VerseKey(
                bookName: favorite.bookName,
                chapterNumber: favorite.chapterNumber,
                verseNumber: favorite.verseNumber
            )
            if !seen.insert(key).inserted {
                context.delete(favorite)
                removed = true
            }
        }
        return removed
    }

    /// Merges duplicate notes for the same verse into the most recently edited one.
    /// A duplicate whose written content differs is kept so no user writing is lost.
    private static func dedupeVerseNotes(in context: ModelContext) -> Bool {
        guard let notes = try? context.fetch(FetchDescriptor<VerseNote>()), notes.count > 1 else { return false }

        let groups = Dictionary(grouping: notes) {
            VerseKey(bookName: $0.bookName, chapterNumber: $0.chapterNumber, verseNumber: $0.verseNumber)
        }

        var removed = false
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted {
                ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
            }
            guard let primary = ordered.first else { continue }

            for duplicate in ordered.dropFirst() {
                guard duplicate.hasSameWriting(as: primary) else { continue }

                if primary.highlightColor.isEmpty && !duplicate.highlightColor.isEmpty {
                    primary.highlightColor = duplicate.highlightColor
                }
                if duplicate.isFavorite {
                    primary.isFavorite = true
                }
                if let duplicateCreated = duplicate.createdAt,
                   duplicateCreated < (primary.createdAt ?? .distantFuture) {
                    primary.createdAt = duplicateCreated
                }
                context.delete(duplicate)
                removed = true
            }
        }
        return removed
    }
}

private extension VerseNote {
    /// Whether the two notes hold the same written content (or one holds none).
    func hasSameWriting(as other: VerseNote) -> Bool {
        let title = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = self.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty && content.isEmpty { return true }

        return title == other.title.trimmingCharacters(in: .whitespacesAndNewlines)
            && content == other.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
