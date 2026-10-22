import Foundation
import SwiftData
import WidgetKit

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
        // Runs whenever synced records may arrive, so text saved by older versions is
        // cleaned here too.
        let cleanedText = StoredVerseTextCleaner.cleanModels(in: context)
        // Before deduplicating, so a record moved to its correct verse merges with any
        // copy already saved there.
        let renumbered = SavedVerseRenumberRepair.run(in: context)
        let removedFavorites = dedupeFavorites(in: context)
        let removedBookmarks = dedupeBookmarks(in: context)
        let removedNotes = dedupeVerseNotes(in: context)
        guard cleanedText || renumbered || removedFavorites || removedBookmarks || removedNotes else { return }
        context.saveLoggingErrors()
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

    /// Keeps the earliest bookmark for each verse.
    private static func dedupeBookmarks(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Bookmark>(
            sortBy: [SortDescriptor(\Bookmark.createdAt, order: .forward)]
        )
        guard let bookmarks = try? context.fetch(descriptor), bookmarks.count > 1 else { return false }

        var seen = Set<VerseKey>()
        var removed = false
        for bookmark in bookmarks {
            let key = VerseKey(
                bookName: bookmark.bookName,
                chapterNumber: bookmark.chapterNumber,
                verseNumber: bookmark.verseNumber
            )
            if !seen.insert(key).inserted {
                context.delete(bookmark)
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

/// Removes KJV translator markup from verse text saved before the Bible text was cleaned
/// at load time (favorites, bookmarks, notes, and verses copied for Home and the widgets).
@MainActor
enum StoredVerseTextCleaner {
    private static let defaultsCleanedKey = AppStorageKey.didCleanSavedVerseTextV1

    /// Cleans favorites, bookmarks, and notes. Returns whether any record changed.
    static func cleanModels(in context: ModelContext) -> Bool {
        var changed = false
        for favorite in (try? context.fetch(FetchDescriptor<Favorite>())) ?? [] where needsCleaning(favorite.verseText) {
            favorite.verseText = KJVTextCleaner.clean(favorite.verseText).text
            changed = true
        }
        for bookmark in (try? context.fetch(FetchDescriptor<Bookmark>())) ?? [] where needsCleaning(bookmark.verseText) {
            bookmark.verseText = KJVTextCleaner.clean(bookmark.verseText).text
            changed = true
        }
        for note in (try? context.fetch(FetchDescriptor<VerseNote>())) ?? [] where needsCleaning(note.verseText) {
            note.verseText = KJVTextCleaner.clean(note.verseText).text
            changed = true
        }
        return changed
    }

    /// Cleans verse text copied into settings for Verse of the Day, the pinned verse,
    /// and Last Read. Runs once, at launch, before any screen reads those values.
    static func cleanSavedTextIfNeeded() {
        let standard = UserDefaults.standard
        guard !standard.bool(forKey: defaultsCleanedKey) else { return }

        clean(key: AppStorageKey.verseOfDayText, in: standard)
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            for key in ["verseOfDayText", "pinnedVerseText", "lastReadText"] {
                clean(key: key, in: shared)
            }
        }
        let cloud = NSUbiquitousKeyValueStore.default
        if let text = cloud.string(forKey: AppStorageKey.lastReadText), needsCleaning(text) {
            cloud.set(KJVTextCleaner.clean(text).text, forKey: AppStorageKey.lastReadText)
        }

        standard.set(true, forKey: defaultsCleanedKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func clean(key: String, in defaults: UserDefaults) {
        guard let text = defaults.string(forKey: key), needsCleaning(text) else { return }
        defaults.set(KJVTextCleaner.clean(text).text, forKey: key)
    }

    private static func needsCleaning(_ text: String) -> Bool {
        text.contains { $0 == "{" || $0 == "}" || $0 == "\u{E000}" || $0 == "\u{E001}" }
    }
}
