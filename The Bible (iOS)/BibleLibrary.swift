import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class BibleStore {
    static let shared = BibleStore()

    private(set) var books: [Book] = []
    private(set) var isReady = false
    /// The bundled Bible text couldn't be read. Screens show `BibleLoadFailedView`.
    private(set) var loadFailed = false
    /// The translation `books` and `BibleData.books` hold. Screens that keep verse text
    /// reload it when this changes.
    private(set) var translation = BibleRepository.shared.activeTranslation
    /// A newly chosen translation is loading; the current one stays until it's ready.
    private(set) var isSwitchingTranslation = false

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    private init() {}

    func ensureLoaded() {
        guard !isReady, loadTask == nil else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            _ = await BibleRepository.shared.loadAllBooks()
            // Read the cache rather than the result: a translation chosen during the load
            // has replaced it.
            books = BibleRepository.shared.cachedBooks
            loadFailed = books.isEmpty
            isReady = true
            loadTask = nil
        }
    }

    /// Loads the Bible again after a failure.
    func retryLoad() {
        guard loadFailed, loadTask == nil else { return }
        isReady = false
        loadFailed = false
        ensureLoaded()
    }

    /// Switches the whole app to another translation once its text loads.
    func selectTranslation(_ newTranslation: BibleTranslation) {
        guard newTranslation != translation, !isSwitchingTranslation else { return }
        isSwitchingTranslation = true
        Task {
            let loaded = await BibleRepository.shared.activate(newTranslation)
            isSwitchingTranslation = false
            guard !loaded.isEmpty else { return }
            books = loaded
            loadFailed = false
            isReady = true
            translation = newTranslation
            Self.refreshCopiedVerseText(in: loaded)
        }
    }

    /// Verse of the Day and Last Read keep a copy of their verse's text for Home and the
    /// widgets. Those copies follow the translation; saved verses keep the text they were
    /// saved with.
    private static func refreshCopiedVerseText(in books: [Book]) {
        func text(book: String?, chapter: Int, verse: Int) -> String? {
            let text = books.first { $0.name == book }?
                .chapters.first { $0.number == chapter }?
                .verses.first { $0.number == verse }?
                .text
            return text?.isEmpty == false ? text : nil
        }

        let standard = UserDefaults.standard
        if let verseOfDayText = text(
            book: standard.string(forKey: AppStorageKey.verseOfDayBook),
            chapter: standard.integer(forKey: AppStorageKey.verseOfDayChapter),
            verse: standard.integer(forKey: AppStorageKey.verseOfDayNumber)
        ) {
            standard.set(verseOfDayText, forKey: AppStorageKey.verseOfDayText)
            BibleTranslation.sharedDefaults?.set(verseOfDayText, forKey: AppStorageKey.verseOfDayText)
        }

        ReadingPositionStore.shared.refreshWidgetText()
        DebouncedWidgetReloader.shared.reload(kind: "VerseWidget")
        DebouncedWidgetReloader.shared.reload(kind: "RandomVerseLockScreenWidget")
    }

    func bookNames() async -> [String] {
        await BibleRepository.shared.bookNames()
    }

    func book(named name: String) async -> Book? {
        if let existing = books.first(where: { $0.name == name }) {
            return existing
        }
        guard let loaded = await BibleRepository.shared.loadBook(named: name) else {
            return nil
        }
        if !books.contains(where: { $0.name == loaded.name }) {
            books.append(loaded)
        }
        return loaded
    }
}

/// Shown in place of the books when the Bible text couldn't be loaded.
struct BibleLoadFailedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Bible Unavailable", systemImage: "book.closed")
        } description: {
            Text("The Bible text couldn’t be loaded. Try again, or reinstall the app if this keeps happening.")
        } actions: {
            Button("Try Again") {
                BibleStore.shared.retryLoad()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
