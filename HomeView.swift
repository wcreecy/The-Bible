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
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

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

    @State private var showCopyToast: Bool = false
    @State private var verseActionToastSymbol: String = "doc.on.doc"
    @State private var verseActionToastText: String = "Copied to Clipboard"
    @State private var verseActionToastTint: Color = .accentColor
    @State private var showFocusSavedToast: Bool = false
    @State private var lastVerseAutoRefreshToken: String = ""

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    private var isPad: Bool { horizontalSizeClass == .regular }
    var progress: ReadingProgress? {
        progressList.first
    }

    // Verse-of-the-Day: configurable times and scheduler (delegated to VM, keep keys observed)
    @AppStorage("votdRefreshFrequency") private var votdRefreshFrequency: String = VOTDRefreshFrequency.custom.rawValue
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0

    // Bible store for async/on-demand loading
    @StateObject private var bibleStore = BibleStore.shared

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

    private func openInBibleTab(_ verse: HomeVerseRef) {
        NotificationCenter.default.post(
            name: .openBibleReference,
            object: nil,
            userInfo: [
                "book": verse.bookName,
                "chapter": verse.chapterNumber,
                "verse": verse.verseNumber
            ]
        )
    }

    // MARK: - Split cards to reduce type-checking complexity

    // Daily goal values for flame progress
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30
    @AppStorage("dailyUsageTodaySeconds") private var dailyUsageTodaySeconds: Int = 0

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

    @State private var layoutOrder: [HomeCardID] = HomeCardID.allCases
    @State private var hiddenCards: Set<HomeCardID> = HomeLayoutStore.baselineHidden
    @State private var showMoreCards: Bool = false
    @State private var hasFavoriteLayout: Bool = false

    private var moreCards: [HomeCardID] {
        layoutOrder.filter {
            ![.verseOfDay, .resumeReading].contains($0) && !hiddenCards.contains($0)
        }
    }

    private func loadHomeLayout() {
        let store = HomeLayoutStore()
        let loaded = store.load()
        layoutOrder = loaded.order
        hiddenCards = loaded.hidden
        hasFavoriteLayout = store.hasFavorite
    }

    private func saveHomeLayout() {
        HomeLayoutStore().save(order: layoutOrder, hidden: hiddenCards)
    }

    private func saveFavoriteLayout() {
        HomeLayoutStore().saveFavorite(order: layoutOrder, hidden: hiddenCards)
        hasFavoriteLayout = true
    }

    private func applyFavoriteLayout() {
        let store = HomeLayoutStore()
        store.applyFavoriteIfAvailable()
        loadHomeLayout()
    }

    // Helper to switch tabs via enum (with backward-compatible Int payload)
    private func switchTo(_ tab: AppTab) {
        NotificationCenter.default.post(
            name: .switchToTab,
            object: nil,
            userInfo: [
                "tab": tab.rawValue,    // legacy Int listeners
                "tabName": tab.name     // new enum-aware listeners
            ]
        )
    }

    @ViewBuilder
    private func card(for id: HomeCardID) -> some View {
        switch id {
        case .verseOfDay:
            VerseOfDayCard(
                verseOfDay: $votdVM.verse,
                verseOfDayPaused: $votdVM.paused,
                isBibleStoreReady: bibleStore.isReady,
                nextRefreshDescription: votdVM.nextRefreshDescription,
                onRefresh: { votdVM.refreshNow() },
                onVerseActionFeedback: handleVerseActionFeedback,
                onOpenReader: { verse in
                    openInBibleTab(verse)
                },
                onTogglePaused: {
                    votdVM.togglePaused()
                },
                title: verseCardTitle,
                icon: verseCardIcon
            )
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.selection()
                guard let verse = votdVM.verse else { return }
                openInBibleTab(verse)
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
                        Haptics.selection()
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
                    switchTo(.games)
                },
                onOpenStats: {
                    // Force StatsView to open on the Game Stats tab
                    UserDefaults.standard.set("Game Stats", forKey: "statsSelectedMode")
                    NotificationCenter.default.post(name: .openStats, object: nil)
                },
                onShufflePlay: {
                    // Choose one of the seven games at random (includes Who am I? and Wordle)
                    enum Game: CaseIterable { case quiz, beat, match, order, hangman, whoami, wordle }
                    let pick = Game.allCases.randomElement() ?? .quiz
                    switch pick {
                    case .quiz:
                        coordinator.push(.gameQuiz)
                    case .beat:
                        coordinator.push(.gameBeatTheClock)
                    case .match:
                        coordinator.push(.gameVerseMatch)
                    case .order:
                        coordinator.push(.gameBookOrder)
                    case .hangman:
                        coordinator.push(.gameHangman)
                    case .whoami:
                        coordinator.push(.gameWhoAmI)
                    case .wordle:
                        coordinator.push(.gameWordle)
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
                    // Force StatsView to open on the Reading Stats tab
                    UserDefaults.standard.set("Reading Stats", forKey: "statsSelectedMode")
                    NotificationCenter.default.post(name: .openStats, object: nil)
                }
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TitleCardView(
                    isPad: isPad,
                    goalMinutes: dailyGoalMinutes,
                    todayReadingSeconds: bibleVM.todaySeconds,
                    streak: StreakTracker.currentStreak,
                    onSearch: {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .openBibleSearch, object: nil)
                        }
                    },
                    onRead: {
                        DispatchQueue.main.async { switchTo(.bible) }
                    },
                    onFavorites: {
                        DispatchQueue.main.async { switchTo(.favorites) }
                    }
                )

                if contextualTipsEnabled {
                    ContextualTipView(
                        title: "Explore more on Home",
                        message: "Expand Show More for prayer timers and other cards. You can choose and reorder Home cards in Settings.",
                        systemImage: "sparkles"
                    )
                }

                if !hiddenCards.contains(.verseOfDay) {
                    card(for: .verseOfDay)
                }

                if !hiddenCards.contains(.resumeReading) {
                    card(for: .resumeReading)
                }

                if !moreCards.isEmpty {
                    Button {
                        withAnimation(.snappy) {
                            showMoreCards.toggle()
                        }
                    } label: {
                        HStack {
                            Label(
                                showMoreCards ? "Show Less" : "Show More",
                                systemImage: "square.grid.2x2"
                            )
                            Spacer()
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(showMoreCards ? 180 : 0))
                        }
                        .font(.headline)
                        .padding(AppDesignMetrics.cardPadding)
                        .imageOverlaySurface()
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(showMoreCards ? "Hides additional Home cards" : "Shows additional Home cards")

                    if showMoreCards {
                        ForEach(moreCards) { cardID in
                            card(for: cardID)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                NavigationLink {
                    HomeLayoutEditorView(
                        order: $layoutOrder,
                        hiddenSet: $hiddenCards,
                        onDone: saveHomeLayout,
                        onSaveFavorite: saveFavoriteLayout,
                        onResetToFavorite: applyFavoriteLayout,
                        hasFavorite: hasFavoriteLayout
                    )
                } label: {
                    Label("Customize Home", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
            }
            .padding(.horizontal, isPad ? 24 : 16)
        }
        .background(AppBackgroundView(tab: .home))
        .navigationTitle("")
        .appToast(
            isPresented: $showCopyToast,
            symbol: verseActionToastSymbol,
            text: verseActionToastText,
            tint: verseActionToastTint
        )
        .appToast(isPresented: $showFocusSavedToast, symbol: "checkmark.seal.fill", text: "Focus Saved", tint: .green)
        .onAppear {
            loadHomeLayout()
            Task { _ = await BibleLibrary.shared.bookNames() }
            bibleStore.ensureLoaded()

            if prayerMode == .focus { prayerMode = .timer }

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
        .onReceive(NotificationCenter.default.publisher(for: .homeLayoutChanged)) { _ in
            loadHomeLayout()
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
        .onChange(of: votdRefreshFrequency) { _, _ in votdVM.refreshScheduleChanged() }
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

    private func handleVerseActionFeedback(_ feedback: VerseActionFeedback) {
        switch feedback {
        case .addedFavorite:
            verseActionToastSymbol = "heart.fill"
            verseActionToastText = "Added to Favorites"
            verseActionToastTint = .pink
        case .removedFavorite:
            verseActionToastSymbol = "heart.slash"
            verseActionToastText = "Removed Favorite"
            verseActionToastTint = .secondary
        case .bookmarked:
            verseActionToastSymbol = "bookmark.fill"
            verseActionToastText = "Set as Continue Reading"
            verseActionToastTint = .accentColor
        case .pinned:
            verseActionToastSymbol = "pin.fill"
            verseActionToastText = "Pinned to Widget"
            verseActionToastTint = .red
        case .unpinned:
            verseActionToastSymbol = "pin"
            verseActionToastText = "Unpinned from Widget"
            verseActionToastTint = .red
        case .copied:
            verseActionToastSymbol = "doc.on.doc"
            verseActionToastText = "Copied to Clipboard"
            verseActionToastTint = .accentColor
        }

        withAnimation(.spring()) {
            showCopyToast = true
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

}

// Note: HeroCard, button styles, DayCell, WeekRow,
// PrayerStudyTimerSetupView, and DebouncedWidgetReloader have been
// moved to their own files as part of UI extraction.
