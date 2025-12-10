// the entire code of the file with your changes goes here.
// Do not skip over anything.
import SwiftUI
import SwiftData
import Combine
import UserNotifications
import AudioToolbox
import UIKit
import HealthKit
import Foundation
import WidgetKit

// Shared types moved to HomeTypes.swift
// private enum VerseScope: String { case old, new, whole, book }

// New: identifiers matching SettingsView’s reorderable/hideable cards
// private enum HomeCardID: String, CaseIterable, Identifiable {
//     case verseOfDay
//     case dailyFocus
//     case timer
//     case resumeReading
//     case streaks // Daily Bible Streak (now includes Daily Goal progress)
//     case games   // Games
//     case bibleStats // NEW: Bible Stats (Top 5 by reading time)
//     var id: String { rawValue }
// }

struct HomeView: View {
    // Visibility widened so split cards can reference it
    enum PrayerMode: String { case timer, stopwatch, focus }

    // Always keep newest progress first so `progressList.first` is canonical
    @Query(sort: \ReadingProgress.updatedAt, order: .reverse) private var progressList: [ReadingProgress]
    @State private var showPrayerStudySheet: Bool = false

    // Timer is now owned by controller
    @StateObject private var timerController = PrayerTimerController()
    // New: Stopwatch controller
    @StateObject private var stopwatchController = StopwatchController()

    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""
    @AppStorage("prayerMode") private var prayerMode: PrayerMode = .timer

    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    // Focus UI-only state (kept in HomeView)
    @FocusState private var focusTitleIsFocused: Bool
    @FocusState private var focusBodyIsFocused: Bool
    @State private var isFocusBodyExpanded: Bool = false

    // Finish alert presented by the controller
    @State private var finishHapticTimer: Timer? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var journalComposer: JournalComposer

    @State private var showCopyToast: Bool = false
    @State private var showFocusSavedToast: Bool = false
    @State private var lastVerseAutoRefreshToken: String = ""
    @State private var isHealthKitAvailable: Bool = HealthKitManager.shared.isAvailable()

    @Environment(\.scenePhase) private var scenePhase

    private var timerTintColor: Color {
        if timerController.remainingSeconds > 300 {
            return .green
        } else if timerController.remainingSeconds > 120 {
            return .yellow
        } else {
            return .red
        }
    }

    private var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 5
    }

    private var verseCardTitle: String { isEvening ? "Word of the Night" : "Verse of the Day" }
    private var verseCardIcon: String { isEvening ? "moon.stars" : "sun.max.fill" }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var iPadCardHeight: CGFloat { 200 }

    private var isEditingFocus: Bool {
        prayerMode == .focus && (focusTitleIsFocused || focusBodyIsFocused)
    }

    var progress: ReadingProgress? {
        progressList.first
    }

    // Verse-of-the-Day: configurable times and scheduler (delegated to VM, keep keys observed)
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0

    // Bible store for async/on-demand loading
    @StateObject private var bibleStore = BibleStore.shared

    // Debounced widget reload helper
    private func debouncedReloadAllWidgets() {
        DebouncedWidgetReloader.shared.reloadAll()
    }

    private func debouncedReload(kind: String) {
        DebouncedWidgetReloader.shared.reload(kind: kind)
    }

    private func mirrorLastReadToAppGroup() {
        guard let shared = sharedDefaults else { return }
        guard let p = progress else { return }
        if let book = BibleData.books.first(where: { $0.name == p.bookName }),
           let chapter = book.chapters.first(where: { $0.number == p.chapterNumber }),
           let verse = chapter.verses.first(where: { $0.number == p.verseNumber }) {
            shared.set(p.bookName, forKey: "lastReadBook")
            shared.set(p.chapterNumber, forKey: "lastReadChapter")
            shared.set(p.verseNumber, forKey: "lastReadVerse")
            shared.set(verse.text, forKey: "lastReadText")
            DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
        }
    }

    private func handleOpenPendingVerse() {
        guard let shared = sharedDefaults else { return }
        guard let book = shared.string(forKey: "pendingOpenBook"),
              let chapter = shared.value(forKey: "pendingOpenChapter") as? Int,
              let verse = shared.value(forKey: "pendingOpenVerse") as? Int else { return }
        shared.removeObject(forKey: "pendingOpenBook")
        shared.removeObject(forKey: "pendingOpenChapter")
        shared.removeObject(forKey: "pendingOpenVerse")

        let books = bibleStore.isReady ? bibleStore.books : []
        guard let b = books.first(where: { $0.name == book }),
              let c = b.chapters.first(where: { $0.number == chapter }) else { return }
        coordinator.push(.reader(book: b, chapter: c, startVerse: verse))
    }

    // MARK: - Split cards to reduce type-checking complexity

    // Daily goal values for flame progress
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30
    @AppStorage("dailyUsageTodaySeconds") private var dailyUsageTodaySeconds: Int = 0

    private func goalMinutesString(_ minutes: Int) -> String {
        let mins = max(0, minutes)
        let hrs = mins / 60
        let rem = mins % 60
        if hrs == 0 { return "\(rem) min" }
        if rem == 0 { return "\(hrs) hr" }
        return "\(hrs) hr \(rem) min"
    }

    // Daily goal values (used inside Streaks card)
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes_streaks: Int = 30
    @AppStorage("dailyUsageTodaySeconds") private var dailyUsageTodaySeconds_streaks: Int = 0
    @AppStorage("dailyUsageTodayKey") private var dailyUsageTodayKey: String = ""

    private var dailyGoalSeconds: Int { max(1, dailyGoalMinutes_streaks) * 60 }
    private var dailyProgress: Double {
        let used = max(0, BibleStatsStore.shared.totalForLast(days: 1))
        return min(1.0, Double(used) / Double(dailyGoalSeconds))
    }
    private var remainingSecondsToday: Int {
        let todayKey = BibleStatsStore.isoDateString(Date())
        let used = max(0, BibleStatsStore.shared.loadDailyTotals()[todayKey, default: 0])
        return max(0, dailyGoalSeconds - used)
    }
    private var remainingFormatted: String {
        if remainingSecondsToday == 0 { return "Goal reached" }
        let m = remainingSecondsToday / 60
        let s = remainingSecondsToday % 60
        return "\(m)m \(s)s left"
    }

    @ViewBuilder
    private var streaksCard: some View {
        StreaksCard()
    }

    // MARK: - Dynamic body using saved layout

    @StateObject private var votdVM = VerseOfDayViewModel()
    @StateObject private var focusVM = FocusViewModel()
    @StateObject private var bibleVM = HomeBibleStatsViewModel()

    // NEW: Bind Live Activities setting directly so Home tracks Settings in real time.
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    @ViewBuilder
    private func card(for id: SettingsView.HomeCardID) -> some View {
        switch id {
        case .verseOfDay:
            VerseOfDayCard(
                verseOfDay: $votdVM.verse,
                verseOfDayPaused: $votdVM.paused,
                isBibleStoreReady: bibleStore.isReady,
                nextRefreshDescription: votdVM.nextRefreshDescription,
                onRefresh: { votdVM.refreshNow() },
                onCopy: { v in copyVerse(v) },
                onShareText: { v in shareText(bookName: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText) },
                isFavorited: { v in isFavorited(v) },
                onToggleFavorite: { v in toggleFavorite(for: v) },
                onOpenReader: { v in
                    guard let book = BibleData.books.first(where: { $0.name == v.bookName }),
                          let chapter = book.chapters.first(where: { $0.number == v.chapterNumber }) else { return }
                    coordinator.push(.reader(book: book, chapter: chapter, startVerse: v.verseNumber))
                },
                onTogglePaused: {
                    votdVM.togglePaused()
                },
                title: verseCardTitle,
                icon: verseCardIcon
            )
            .contentShape(Rectangle())
            .onTapGesture {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                guard let v = votdVM.verse,
                      let book = BibleData.books.first(where: { $0.name == v.bookName }),
                      let chapter = book.chapters.first(where: { $0.number == v.chapterNumber }) else { return }
                coordinator.push(.reader(book: book, chapter: chapter, startVerse: v.verseNumber))
            }
        case .dailyFocus:
            DailyFocusCard(
                focusTitle: $focusVM.title,
                focusBody: $focusVM.body,
                hasSavedFocus: $focusVM.hasSaved,
                focusSavedAt: $focusVM.savedAt,
                focusTitleIsFocused: _focusTitleIsFocused.projectedValue,
                focusBodyIsFocused: _focusBodyIsFocused.projectedValue,
                isFocusBodyExpanded: $isFocusBodyExpanded,
                liveActivitiesEnabled: liveActivitiesEnabled,
                onSave: {
                    focusVM.save()
                    focusTitleIsFocused = false
                    focusBodyIsFocused = false
                    withAnimation(.spring()) { showFocusSavedToast = true }
                },
                onClear: {
                    focusVM.clear()
                    focusTitleIsFocused = false
                    focusBodyIsFocused = false
                    isFocusBodyExpanded = false
                },
                onEnableLiveActivities: {
                    NotificationCenter.default.post(name: .openSettingsTab, object: nil)
                }
            )
        case .timer:
            if prayerMode == .timer {
                PrayerTimerCard(
                    prayerMode: $prayerMode,
                    isTimerRunning: timerController.isRunning,
                    isPaused: timerController.isPaused,
                    remainingSeconds: timerController.remainingSeconds,
                    timerTintColor: timerTintColor,
                    formattedTime: { TimeFormatters.compactClock($0) },
                    onOpenSetup: {
                        if isHealthKitAvailable && !(UserDefaults.standard.bool(forKey: "healthKitPrompted")) {
                            Task { await requestHealthKitIfNeededForTimer() }
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        showPrayerStudySheet = true
                    },
                    onStartPreset: { minutes in
                        timerController.start(minutes: minutes)
                    },
                    onTogglePause: { timerController.togglePause() },
                    onAddOne: { timerController.addOne() },
                    onAddFive: { timerController.addFive() },
                    onAddTen: { timerController.addTen() },
                    onStop: { timerController.stop() },
                    stopwatchRunning: stopwatchController.isRunning,
                    modePicker: { disabled in AnyView(ModePicker(prayerMode: $prayerMode, disabled: disabled)) }
                )
            } else {
                StopwatchCard(
                    prayerMode: $prayerMode,
                    stopwatchRunning: stopwatchController.isRunning,
                    stopwatchElapsed: stopwatchController.elapsed,
                    formattedStopwatch: { TimeFormatters.compactStopwatch($0) },
                    onStart: { stopwatchController.start() },
                    onPause: { stopwatchController.pause() },
                    onStop: { stopwatchController.stop() },
                    isTimerRunning: timerController.isRunning,
                    modePicker: { disabled in AnyView(ModePicker(prayerMode: $prayerMode, disabled: disabled)) }
                )
            }
        case .resumeReading:
            ResumeReadingCard(
                progress: progress,
                onOpenReference: { p in
                    NotificationCenter.default.post(
                        name: .openBibleReference,
                        object: nil,
                        userInfo: [
                            "book": p.bookName,
                            "chapter": p.chapterNumber,
                            "verse": p.verseNumber
                        ]
                    )
                }
            )
        case .games:
            GamesCard(
                onOpenGames: {
                    NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 3])
                },
                onOpenStats: {
                    NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 6])
                },
                onShufflePlay: {
                    // Choose one of the five games at random
                    enum Game: CaseIterable { case quiz, beat, match, order, hangman }
                    let pick = Game.allCases.randomElement() ?? .quiz
                    switch pick {
                    case .quiz:
                        coordinator.push(.gameQuiz)
                    case .beat:
                        coordinator.push(.gameBeatTheClock)
                    case .match:
                        coordinator.push(.gameReferenceMatch)
                    case .order:
                        coordinator.push(.gameBookOrder)
                    case .hangman:
                        coordinator.push(.gameHangman)
                    }
                }
            )
        case .streaks:
            streaksCard
        case .bibleStats:
            BibleStatsCard(
                bibleVM: bibleVM,
                scenePhase: scenePhase,
                onOpenStats: {
                    NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 6])
                }
            )
        }
    }

    var body: some View {
        // Load from centralized layout store
        let store = HomeLayoutStore()
        let loaded = store.load()
        // Keep state for dynamic updates
        let activeCards: [SettingsView.HomeCardID] = loaded.order.filter { !loaded.hidden.contains($0) }

        ScrollView {
            if isPad {
                let leftCards = activeCards.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
                let rightCards = activeCards.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }

                VStack(spacing: 16) {
                    TitleCardView(
                        isPad: isPad,
                        goalMinutes: dailyGoalMinutes,
                        todayReadingSeconds: bibleVM.todaySeconds,
                        streak: StreakTracker.currentStreak,
                        onSearch: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 5])
                            }
                        },
                        onRead: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 1])
                            }
                        },
                        onFavorites: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 4])
                            }
                        }
                    )

                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) {
                            ForEach(leftCards, id: \.self) { id in
                                card(for: id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        VStack(spacing: 16) {
                            ForEach(rightCards, id: \.self) { id in
                                card(for: id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 16) {
                    TitleCardView(
                        isPad: isPad,
                        goalMinutes: dailyGoalMinutes,
                        todayReadingSeconds: bibleVM.todaySeconds,
                        streak: StreakTracker.currentStreak,
                        onSearch: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 5])
                            }
                        },
                        onRead: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 1])
                            }
                        },
                        onFavorites: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 4])
                            }
                        }
                    )

                    ForEach(loaded.order, id: \.self) { cardID in
                        if !loaded.hidden.contains(cardID) {
                            card(for: cardID)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
        .appToast(isPresented: $showFocusSavedToast, symbol: "checkmark.seal.fill", text: "Focus Saved", tint: .green)
        .onAppear {
            Task { _ = await BibleLibrary.shared.bookNames() }
            bibleStore.ensureLoaded()

            if prayerMode == .focus { prayerMode = .timer }

            isHealthKitAvailable = HealthKitManager.shared.isAvailable()

            // Verse-of-the-Day initial handling moved to VM
            votdVM.handleAppear()

            // Focus initial load
            focusVM.loadFromStorage()

            dedupeReadingProgress()

            mirrorLastReadToAppGroup()
            handleOpenPendingVerse()

            // Controllers
            timerController.onAppear()
            _ = timerController.handlePendingActionIfAny()

            stopwatchController.onAppear()
            _ = stopwatchController.handlePendingActionIfAny()

            // Initial load of Bible Stats
            bibleVM.refresh()

            // Initialize GameStats and bind to its version for immediate refresh
            gameStatsVersion = GameStats.shared.snapshot().totalAnswered
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("homeLayoutChanged"))) { _ in
            // Trigger a refresh by changing a token state if needed, or rely on recomputation via body
        }
        .onChange(of: progressList) { _, _ in
            mirrorLastReadToAppGroup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                _ = timerController.handlePendingActionIfAny()
                _ = stopwatchController.handlePendingActionIfAny()
                handleOpenPendingVerse()
                bibleVM.refresh()
                votdVM.handleScenePhaseChange(newPhase)
                timerController.onSceneBecameActive()
                stopwatchController.onSceneBecameActive()
            case .inactive, .background:
                timerController.onSceneBecameInactiveOrBackground()
                stopwatchController.onSceneBecameInactiveOrBackground()
            @unknown default:
                break
            }
        }
        // Forward VOTD schedule changes to the VM
        .onChange(of: votdRefresh1Hour) { _, _ in votdVM.refreshScheduleChanged() }
        .onChange(of: votdRefresh1Minute) { _, _ in votdVM.refreshScheduleChanged() }
        .onChange(of: votdRefresh2Hour) { _, _ in votdVM.refreshScheduleChanged() }
        .onChange(of: votdRefresh2Minute) { _, _ in votdVM.refreshScheduleChanged() }
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            // bibleVM already refreshes on appear/active
        }
        .sheet(isPresented: $showPrayerStudySheet) {
            PrayerStudyTimerSetupView(onStart: { minutes in
                timerController.start(minutes: minutes)
                showPrayerStudySheet = false
            })
            .presentationDetents([.medium, .large])
        }
        .alert("Prayer/Study Finished", isPresented: $timerController.showFinishedAlert) {
            Button("Dismiss", role: .cancel) {
                timerController.stopFinishAlerts()
                timerController.showFinishedAlert = false
            }
        } message: {
            Text("Your prayer/study timer has completed.")
        }
    }

    private func copyVerse(_ v: HomeVerseRef) {
        UIPasteboard.general.string = shareText(bookName: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText)
        withAnimation(.spring()) { showCopyToast = true }
    }

    private func isFavorited(_ v: HomeVerseRef) -> Bool {
        favorites.contains { fav in
            fav.bookName == v.bookName && fav.chapterNumber == v.chapterNumber && fav.verseNumber == v.verseNumber
        }
    }

    private func toggleFavorite(for v: HomeVerseRef) {
        if let existing = favorites.first(where: { $0.bookName == v.bookName && $0.chapterNumber == v.chapterNumber && $0.verseNumber == v.verseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(bookName: v.bookName, chapterNumber: v.chapterNumber, verseNumber: v.verseNumber, verseText: v.verseText)
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }

    // MARK: - Small helpers moved out of ViewBuilder to avoid result-builder declaration errors

    private func uniqueMaxIndex<T: Comparable & Equatable>(_ values: [T]) -> Int? {
        guard let maxVal = values.max() else { return nil }
        let indices = values.enumerated().filter { $0.element == maxVal }.map { $0.offset }
        return indices.count == 1 ? indices.first : nil
    }

    private func uniqueMinIndex<T: Comparable & Equatable>(_ values: [T]) -> Int? {
        guard let minVal = values.min() else { return nil }
        let indices = values.enumerated().filter { $0.element == minVal }.map { $0.offset }
        return indices.count == 1 ? indices.first : nil
    }

    // MARK: - ReadingProgress safety dedupe on Home (one-time)
    private func dedupeReadingProgress() {
        guard progressList.count > 1 else { return }
        let toDelete = progressList.dropFirst()
        for p in toDelete {
            modelContext.delete(p)
        }
        try? modelContext.save()
    }

    // MARK: - NEW: Games Card (Home) using centralized GameStats
    @State private var gameStatsVersion: Int = 0

    // Permissions helper for timer setup
    private func requestHealthKitIfNeededForTimer() async {
        guard HealthKitManager.shared.isAvailable() && !(UserDefaults.standard.bool(forKey: "healthKitPrompted")) else { return }
        await withCheckedContinuation { continuation in
            HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
                Task { @MainActor in
                    UserDefaults.standard.set(true, forKey: "healthKitPrompted")
                }
                continuation.resume()
            }
        }
    }
}

// Note: HeroCard, button styles, DayCell, WeekRow,
// PrayerStudyTimerSetupView, and DebouncedWidgetReloader have been
// moved to their own files as part of UI extraction.
