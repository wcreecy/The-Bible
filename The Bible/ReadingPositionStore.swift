import Foundation
import Observation
import SwiftData
import WidgetKit

extension Notification.Name {
    /// Posted when the reading position changes on this device or arrives from another.
    static let readingPositionChanged = Notification.Name("readingPositionChanged")
}

/// The single "where I stopped" position, saved automatically while reading and synced
/// across devices (newest wins). It drives Continue Reading, the Bible tab at launch,
/// the Last Read widget, and Stats.
///
/// Stored as `BibleStatsStore`'s last-read entry, which already syncs through
/// `iCloudSyncCoordinator`.
@MainActor
@Observable
final class ReadingPositionStore {
    static let shared = ReadingPositionStore()

    /// The latest position, including updates not yet written to storage.
    private(set) var current: BibleStatsStore.LastRead?

    @ObservationIgnored private var pending: BibleStatsStore.LastRead?
    @ObservationIgnored private var commitTask: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?

    /// Scrolling moves the position many times a second; storage and sync are updated
    /// once it has been stable for this long.
    private static let commitDelay: Duration = .seconds(2)
    private static let widgetDefaults = UserDefaults(suiteName: "group.bible.app")
    private static let migrationKey = "didMigrateReadingPositionV1"

    private init() {
        current = BibleStatsStore.shared.loadLastRead()
        // Positions merged from iCloud arrive through the stats store.
        observer = NotificationCenter.default.addObserver(
            forName: .bibleStatsExternallyUpdated,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                ReadingPositionStore.shared.reloadFromStorage()
            }
        }
    }

    // MARK: - Updating

    /// Records where the reader is. Repeated calls while scrolling are coalesced.
    func record(bookName: String, chapter: Int, verse: Int) {
        guard !bookName.isEmpty, chapter > 0, verse > 0 else { return }
        if let current,
           current.bookName == bookName,
           current.chapterNumber == chapter,
           current.verseNumber == verse {
            return
        }

        let position = BibleStatsStore.LastRead(
            bookName: bookName,
            chapterNumber: chapter,
            verseNumber: verse,
            date: Date()
        )
        current = position
        pending = position

        commitTask?.cancel()
        commitTask = Task { [weak self] in
            try? await Task.sleep(for: Self.commitDelay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Writes any pending position now, such as when leaving the reader or the app.
    func flush() {
        commitTask?.cancel()
        commitTask = nil
        guard let position = pending else { return }
        pending = nil

        BibleStatsStore.shared.saveLastRead(
            bookName: position.bookName,
            chapterNumber: position.chapterNumber,
            verseNumber: position.verseNumber,
            date: position.date,
            notify: false
        )
        ReadingTimeHistory.recordReading(at: position.date)
        mirrorToWidget(position)
        NotificationCenter.default.post(name: .readingPositionChanged, object: nil)
    }

    /// Forgets the position, for example after reading statistics are reset.
    func clear() {
        commitTask?.cancel()
        commitTask = nil
        pending = nil
        current = nil
        BibleStatsStore.shared.clearLastRead()
        mirrorToWidget(nil)
        NotificationCenter.default.post(name: .readingPositionChanged, object: nil)
    }

    private func reloadFromStorage() {
        guard pending == nil else { return }
        let stored = BibleStatsStore.shared.loadLastRead()
        guard stored != current else { return }
        current = stored
        mirrorToWidget(stored)
        NotificationCenter.default.post(name: .readingPositionChanged, object: nil)
    }

    // MARK: - Widget

    /// The Last Read widget reads this copy from the shared app group.
    private func mirrorToWidget(_ position: BibleStatsStore.LastRead?) {
        guard let shared = Self.widgetDefaults else { return }
        let keys = ["lastReadBook", "lastReadChapter", "lastReadVerse", "lastReadText"]

        guard let position else {
            keys.forEach { shared.removeObject(forKey: $0) }
            DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
            return
        }

        let verseNumber = position.verseNumber ?? 1
        let text = BibleData.books
            .first { $0.name == position.bookName }?
            .chapters.first { $0.number == position.chapterNumber }?
            .verses.first { $0.number == verseNumber }?
            .text ?? ""
        shared.set(position.bookName, forKey: "lastReadBook")
        shared.set(position.chapterNumber, forKey: "lastReadChapter")
        shared.set(verseNumber, forKey: "lastReadVerse")
        shared.set(text, forKey: "lastReadText")
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
    }

    // MARK: - Migration

    /// Seeds the position once from the records it replaces, so nobody loses their place:
    /// the synced stats entry (chapter only), the verse this device last scrolled to, and
    /// the old manual Continue Reading bookmark.
    func migrateIfNeeded(modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.migrationKey) else { return }
        defer { defaults.set(true, forKey: Self.migrationKey) }

        var best = BibleStatsStore.shared.loadLastRead()

        // The old device-only position added the verse for the same chapter.
        if let book = defaults.string(forKey: "readerPositionBook"), !book.isEmpty {
            let chapter = defaults.integer(forKey: "readerPositionChapter")
            let verse = defaults.integer(forKey: "readerPositionVerse")
            if chapter > 0, verse > 0 {
                if let existing = best, existing.bookName == book, existing.chapterNumber == chapter {
                    best?.verseNumber = existing.verseNumber ?? verse
                } else if best == nil {
                    best = .init(bookName: book, chapterNumber: chapter, verseNumber: verse, date: .distantPast)
                }
            }
        }

        // A newer manual Continue Reading bookmark wins.
        var newestProgress = FetchDescriptor<ReadingProgress>(
            sortBy: [SortDescriptor(\ReadingProgress.updatedAt, order: .reverse)]
        )
        newestProgress.fetchLimit = 1
        if let progress = try? modelContext.fetch(newestProgress).first,
           !progress.bookName.isEmpty, progress.chapterNumber > 0,
           progress.updatedAt > (best?.date ?? .distantPast) {
            best = .init(
                bookName: progress.bookName,
                chapterNumber: progress.chapterNumber,
                verseNumber: max(1, progress.verseNumber),
                date: progress.updatedAt
            )
        }

        for key in ["readerPositionBook", "readerPositionChapter", "readerPositionVerse", "recentBiblePassages"] {
            defaults.removeObject(forKey: key)
        }

        guard let best else { return }
        current = best
        pending = best
        flush()
    }
}
