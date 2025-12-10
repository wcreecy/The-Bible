import Foundation
import SwiftUI
import Combine
import WidgetKit

@MainActor
final class VerseOfDayViewModel: ObservableObject {
    // Published UI state
    @Published var verse: HomeVerseRef?
    @Published var paused: Bool = false
    @Published var nextRefreshDescription: String = ""

    // AppStorage-backed settings/state (same keys as HomeView used)
    @AppStorage("verseOfDayPaused") private var verseOfDayPaused: Bool = false
    @AppStorage("verseOfDayBook") private var storedVerseBook: String = ""
    @AppStorage("verseOfDayChapter") private var storedVerseChapter: Int = 0
    @AppStorage("verseOfDayNumber") private var storedVerseNumber: Int = 0
    @AppStorage("verseOfDayText") private var storedVerseText: String = ""
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""

    // Refresh schedule (same keys)
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0

    // One-shot timer for next auto refresh
    private var nextRefreshTimer: Timer?

    // App group mirror
    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    // External readiness hint for UI
    var isBibleStoreReady: Bool { true }

    init() {
        // Initialize from storage
        paused = verseOfDayPaused
        if !storedVerseBook.isEmpty && storedVerseChapter > 0 && storedVerseNumber > 0 && !storedVerseText.isEmpty {
            verse = HomeVerseRef(
                bookName: storedVerseBook,
                chapterNumber: storedVerseChapter,
                verseNumber: storedVerseNumber,
                verseText: storedVerseText
            )
            mirrorVerseToAppGroup(book: storedVerseBook, chapter: storedVerseChapter, verse: storedVerseNumber, text: storedVerseText)
        }
        updateNextDescription()
        scheduleNextVerseRefreshTimer()
    }

    deinit {
        nextRefreshTimer?.invalidate()
        nextRefreshTimer = nil
    }

    // MARK: - Public API

    func handleAppear() {
        if verse == nil && !paused {
            loadRandomVerse()
        }
        updateNextDescription()
        scheduleNextVerseRefreshTimer()
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            updateNextDescription()
            scheduleNextVerseRefreshTimer()
        default:
            break
        }
    }

    func refreshNow() {
        guard !paused else { return }
        loadRandomVerse()
        updateNextDescription()
        scheduleNextVerseRefreshTimer()
    }

    func togglePaused() {
        let newValue = !paused
        paused = newValue
        verseOfDayPaused = newValue

        if newValue {
            if let v = verse {
                storedVerseBook = v.bookName
                storedVerseChapter = v.chapterNumber
                storedVerseNumber = v.verseNumber
                storedVerseText = v.verseText
                mirrorVerseToAppGroup(book: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText)
            }
            nextRefreshTimer?.invalidate()
            nextRefreshTimer = nil
        } else {
            scheduleNextVerseRefreshTimer()
        }
        updateNextDescription()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Internal helpers

    private func mirrorVerseToAppGroup(book: String, chapter: Int, verse: Int, text: String) {
        guard let shared = sharedDefaults else { return }
        shared.set(book, forKey: "verseOfDayBook")
        shared.set(chapter, forKey: "verseOfDayChapter")
        shared.set(verse, forKey: "verseOfDayNumber")
        shared.set(text, forKey: "verseOfDayText")
        DebouncedWidgetReloader.shared.reload(kind: "VerseWidget")
    }

    private enum VerseScope: String { case old, new, whole, book }

    private func loadRandomVerse() {
        guard !paused else { return }
        let allBooks = BibleData.books
        guard !allBooks.isEmpty else { return }

        let scope = VerseScope(rawValue: verseScopeRaw) ?? .whole
        let books: [Book]
        switch scope {
        case .old:
            books = allBooks.filter { oldTestamentBooks.contains($0.name) }
        case .new:
            books = allBooks.filter { !oldTestamentBooks.contains($0.name) }
        case .whole:
            books = allBooks
        case .book:
            if let chosen = allBooks.first(where: { $0.name == verseSpecificBook }) {
                books = [chosen]
            } else {
                books = allBooks
            }
        }

        guard let book = books.randomElement(),
              let chapter = book.chapters.randomElement(),
              !chapter.verses.isEmpty,
              let v = chapter.verses.randomElement() else { return }

        let ref = HomeVerseRef(bookName: book.name, chapterNumber: chapter.number, verseNumber: v.number, verseText: v.text)
        verse = ref
        storedVerseBook = ref.bookName
        storedVerseChapter = ref.chapterNumber
        storedVerseNumber = ref.verseNumber
        storedVerseText = ref.verseText
        mirrorVerseToAppGroup(book: ref.bookName, chapter: ref.chapterNumber, verse: ref.verseNumber, text: ref.verseText)
    }

    // Centralized schedule helpers

    private func nextAutoRefreshDate(from now: Date = Date()) -> Date {
        VOTDSchedule.nextAutoRefreshDate(
            first: (votdRefresh1Hour, votdRefresh1Minute),
            second: (votdRefresh2Hour, votdRefresh2Minute),
            from: now
        )
    }

    private func updateNextDescription() {
        if paused {
            nextRefreshDescription = "Auto refresh is paused."
            return
        }
        nextRefreshDescription = VOTDSchedule.nextAutoRefreshDescription(
            first: (votdRefresh1Hour, votdRefresh1Minute),
            second: (votdRefresh2Hour, votdRefresh2Minute)
        )
    }

    private func scheduleNextVerseRefreshTimer() {
        nextRefreshTimer?.invalidate()
        guard !paused else { return }
        let next = nextAutoRefreshDate()
        let interval = max(1, next.timeIntervalSinceNow)
        nextRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.loadRandomVerse()
            self.updateNextDescription()
            self.scheduleNextVerseRefreshTimer()
        }
        if let t = nextRefreshTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    // Expose handlers for setting changes
    func refreshScheduleChanged() {
        updateNextDescription()
        scheduleNextVerseRefreshTimer()
    }
}

// Keep in sync with HomeView’s old constant
private let oldTestamentBooks: Set<String> = [
    "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
    "Joshua","Judges","Ruth",
    "1 Samuel","2 Samuel",
    "1 Kings","2 Kings",
    "1 Chronicles","2 Chronicles",
    "Ezra","Nehemiah","Esther",
    "Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon",
    "Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel",
    "Hosea","Joel","Amos","Obadiah","Jonah",
    "Micah","Nahum","Habakkuk","Zephaniah",
    "Haggai","Zechariah","Malachi"
]
