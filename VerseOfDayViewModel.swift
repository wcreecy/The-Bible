import Foundation
import SwiftUI
import Observation
import WidgetKit

@MainActor
@Observable
final class VerseOfDayViewModel {
    // Published UI state
    var verse: HomeVerseRef?
    var paused: Bool = false
    var nextRefreshDescription: String = ""

    // AppStorage-backed settings/state (same keys as HomeView used)
    @ObservationIgnored @AppStorage("verseOfDayPaused") private var verseOfDayPaused: Bool = false
    @ObservationIgnored @AppStorage("verseOfDayBook") private var storedVerseBook: String = ""
    @ObservationIgnored @AppStorage("verseOfDayChapter") private var storedVerseChapter: Int = 0
    @ObservationIgnored @AppStorage("verseOfDayNumber") private var storedVerseNumber: Int = 0
    @ObservationIgnored @AppStorage("verseOfDayText") private var storedVerseText: String = ""
    @ObservationIgnored @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @ObservationIgnored @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""

    // Refresh schedule (same keys)
    @ObservationIgnored @AppStorage("votdRefreshFrequency") private var refreshFrequencyRaw: String = VOTDRefreshFrequency.custom.rawValue
    @ObservationIgnored @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @ObservationIgnored @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @ObservationIgnored @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @ObservationIgnored @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0
    @ObservationIgnored @AppStorage("votdRefreshNotificationsEnabled") private var refreshNotificationsEnabled: Bool = false

    // One-shot timer for next auto refresh
    @ObservationIgnored nonisolated(unsafe) private var nextRefreshTimer: Timer?

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
        mirrorScheduleToAppGroup()
        updateNextDescription()
        scheduleNextVerseRefreshTimer()
        updateRefreshNotificationSchedule()
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
        UserDefaults.standard.set(true, forKey: "homeOnboardingVerseOfDayRefreshedV2")
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
            VOTDNotificationScheduler.cancel()
        } else {
            scheduleNextVerseRefreshTimer()
            updateRefreshNotificationSchedule()
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

    private func mirrorScheduleToAppGroup() {
        guard let shared = sharedDefaults else { return }
        shared.set(refreshFrequencyRaw, forKey: "votdRefreshFrequency")
        shared.set(votdRefresh1Hour, forKey: "votdRefresh1Hour")
        shared.set(votdRefresh1Minute, forKey: "votdRefresh1Minute")
        shared.set(votdRefresh2Hour, forKey: "votdRefresh2Hour")
        shared.set(votdRefresh2Minute, forKey: "votdRefresh2Minute")
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

        // Pick a uniformly random verse without creating a temporary entry for every
        // verse in the corpus. A random offset across the eligible verse count gives
        // every verse the same probability of being selected.
        let eligibleVerseCount = books.reduce(into: 0) { total, book in
            total += book.chapters.reduce(into: 0) { $0 += $1.verses.count }
        }
        guard eligibleVerseCount > 0 else { return }

        var remainingOffset = Int.random(in: 0..<eligibleVerseCount)
        var selection: (book: Book, chapter: Chapter, verse: Verse)?
        selectionLoop: for book in books {
            for chapter in book.chapters {
                if remainingOffset < chapter.verses.count {
                    selection = (book, chapter, chapter.verses[remainingOffset])
                    break selectionLoop
                }
                remainingOffset -= chapter.verses.count
            }
        }

        guard let selection else { return }

        let ref = HomeVerseRef(
            bookName: selection.book.name,
            chapterNumber: selection.chapter.number,
            verseNumber: selection.verse.number,
            verseText: selection.verse.text
        )
        verse = ref
        storedVerseBook = ref.bookName
        storedVerseChapter = ref.chapterNumber
        storedVerseNumber = ref.verseNumber
        storedVerseText = ref.verseText
        // The widget favors itself in Smart Stacks for a while after a new verse.
        sharedDefaults?.set(Date(), forKey: "verseOfDayChangedAt")
        mirrorVerseToAppGroup(book: ref.bookName, chapter: ref.chapterNumber, verse: ref.verseNumber, text: ref.verseText)
    }

    // Centralized schedule helpers

    private func nextAutoRefreshDate(from now: Date = Date()) -> Date {
        VOTDSchedule.nextAutoRefreshDate(
            frequency: VOTDRefreshFrequency(rawValue: refreshFrequencyRaw) ?? .custom,
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
            frequency: VOTDRefreshFrequency(rawValue: refreshFrequencyRaw) ?? .custom,
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
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loadRandomVerse()
                self.updateNextDescription()
                self.scheduleNextVerseRefreshTimer()
            }
        }
        if let t = nextRefreshTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    // Expose handlers for setting changes
    func refreshScheduleChanged() {
        mirrorScheduleToAppGroup()
        DebouncedWidgetReloader.shared.reload(kind: "VerseWidget")
        updateNextDescription()
        scheduleNextVerseRefreshTimer()
        updateRefreshNotificationSchedule()
    }

    private func updateRefreshNotificationSchedule() {
        guard refreshNotificationsEnabled, !paused else {
            VOTDNotificationScheduler.cancel()
            return
        }

        Task {
            await VOTDNotificationScheduler.schedule(
                frequency: VOTDRefreshFrequency(rawValue: refreshFrequencyRaw) ?? .custom,
                first: (votdRefresh1Hour, votdRefresh1Minute),
                second: (votdRefresh2Hour, votdRefresh2Minute)
            )
        }
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
