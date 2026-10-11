import SwiftUI
import SwiftData
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
//     case bibleStats // NEW: Bible Stats (Top 5 by reading time)
//     var id: String { rawValue }
// }

private struct HomeMasonryGrid: Layout {
    let columnCount: Int
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 0
        let result = layoutResult(width: width, subviews: subviews)
        return CGSize(width: width, height: result.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layoutResult(width: bounds.width, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func layoutResult(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        guard columnCount > 0, width > 0, !subviews.isEmpty else {
            return ([], 0)
        }

        let totalSpacing = spacing * CGFloat(columnCount - 1)
        let columnWidth = max(0, (width - totalSpacing) / CGFloat(columnCount))
        let itemProposal = ProposedViewSize(width: columnWidth, height: nil)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        for subview in subviews {
            let column = columnHeights.indices.min {
                columnHeights[$0] < columnHeights[$1]
            } ?? 0
            let top = columnHeights[column] == 0 ? 0 : columnHeights[column] + spacing
            let size = subview.sizeThatFits(itemProposal)
            let origin = CGPoint(
                x: CGFloat(column) * (columnWidth + spacing),
                y: top
            )

            frames.append(CGRect(origin: origin, size: CGSize(width: columnWidth, height: size.height)))
            columnHeights[column] = top + size.height
        }

        return (frames, columnHeights.max() ?? 0)
    }
}

private struct HomeDashboardColumns<Header: View, Tip: View, Main: View, Sidebar: View>: View {
    let columnSpacing: CGFloat
    let mainWidth: CGFloat
    let sidebarWidth: CGFloat
    let header: Header
    let tip: Tip
    let main: Main
    let sidebar: Sidebar

    init(
        columnSpacing: CGFloat,
        mainWidth: CGFloat,
        sidebarWidth: CGFloat,
        @ViewBuilder header: () -> Header,
        @ViewBuilder tip: () -> Tip,
        @ViewBuilder main: () -> Main,
        @ViewBuilder sidebar: () -> Sidebar
    ) {
        self.columnSpacing = columnSpacing
        self.mainWidth = mainWidth
        self.sidebarWidth = sidebarWidth
        self.header = header()
        self.tip = tip()
        self.main = main()
        self.sidebar = sidebar()
    }

    var body: some View {
        header
        tip

        HStack(alignment: .top, spacing: columnSpacing) {
            main
                .frame(width: mainWidth)
            sidebar
                .frame(width: sidebarWidth)
        }
    }
}

struct HomeView: View {
    @State private var showPrayerStudySheet: Bool = false

    private var timerController = PrayerTimerController.shared

    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    // Finish alert presented by the controller
    @State private var finishHapticTimer: Timer? = nil

    @Environment(NavigationCoordinator.self) private var coordinator

    @State private var showCopyToast: Bool = false
    @State private var verseActionToastSymbol: String = "doc.on.doc"
    @State private var verseActionToastText: String = "Copied to Clipboard"
    @State private var verseActionToastTint: Color = .accentColor
    @State private var lastVerseAutoRefreshToken: String = ""

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 5
    }

    private var verseCardTitle: String { isEvening ? "Word of the Night" : "Verse of the Day" }
    private var verseCardIcon: String { isEvening ? "moon.stars" : "sun.max.fill" }

    private var isPad: Bool { horizontalSizeClass == .regular }
    // Newest first; synced devices can briefly hold more than one bookmark.
    @Query(sort: [SortDescriptor(\Bookmark.createdAt, order: .reverse)]) private var bookmarks: [Bookmark]

    /// The verse the reader bookmarked; the single source for Continue Reading.
    /// (The automatic last-read position only drives where the Bible tab opens.)
    private var bookmark: Bookmark? {
        bookmarks.first
    }

    // Verse-of-the-Day: configurable times and scheduler (delegated to VM, keep keys observed)
    @AppStorage("votdRefreshFrequency") private var votdRefreshFrequency: String = VOTDRefreshFrequency.custom.rawValue
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0

    // Bible store for async/on-demand loading
    private var bibleStore = BibleStore.shared

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
        openBibleReference(book: verse.bookName, chapter: verse.chapterNumber, verse: verse.verseNumber)
    }

    private func openBibleReference(book: String, chapter: Int, verse: Int) {
        AppRouter.shared.openBibleReference(book: book, chapter: chapter, verse: verse)
    }

    // MARK: - Split cards to reduce type-checking complexity

    // Daily goal values for flame progress
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    @ViewBuilder
    private var streaksCard: some View {
        StreaksCard(
            onOpenStats: openReadingStats,
            onReadNow: openContinueReading
        )
    }

    private func openReadingStats() {
        AppRouter.shared.open(.stats(.reading))
    }

    /// Whether the Reading Streak card is on screen, so the header can skip repeating it.
    private func isStreaksCardShown(usesDashboard: Bool) -> Bool {
        guard !hiddenCards.contains(.streaks) else { return false }
        return !usesDashboard || !showsMinimalHome
    }

    // MARK: - Dynamic body using saved layout

    @State private var votdVM = VerseOfDayViewModel()
    @State private var focusVM = FocusViewModel()
    @State private var bibleVM = HomeBibleStatsViewModel()

    // NEW: Bind Live Activities setting directly so Home tracks Settings in real time.
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    @State private var layoutOrder: [HomeCardID] = HomeLayoutStore.baselineOrder
    @State private var hiddenCards: Set<HomeCardID> = HomeLayoutStore.baselineHidden
    @State private var hasFavoriteLayout: Bool = false
    /// Incremented by the Search card to ask Home to scroll it into view while typing.
    @State private var searchScrollRequest = 0
    @AppStorage("homeCustomizeButtonVisible") private var customizeButtonVisible = true
    @AppStorage("homeBibleReaderVisible") private var bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible

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
        HomeLayoutStore().saveFavorite(
            order: layoutOrder,
            hidden: hiddenCards,
            bibleReaderVisible: bibleReaderVisible
        )
        hasFavoriteLayout = true
    }

    private func applyFavoriteLayout() {
        let store = HomeLayoutStore()
        store.applyFavoriteIfAvailable()
        loadHomeLayout()
    }

    private func switchTo(_ tab: AppTab) {
        AppRouter.shared.open(.tab(tab))
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
                focus: focusVM,
                liveActivitiesEnabled: liveActivitiesEnabled,
                onEnableLiveActivities: {
                    AppRouter.shared.open(.settings)
                }
            )
        case .timer:
            PrayerTimerCard(
                isTimerRunning: timerController.isRunning,
                isPaused: timerController.isPaused,
                remainingSeconds: timerController.remainingSeconds,
                totalSeconds: timerController.totalSeconds,
                formattedTime: { TimeFormatters.compactClock($0) },
                verseOfDay: votdVM.verse,
                canUndoStop: timerController.undoableStop != nil,
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
                onStop: { timerController.stop() },
                onUndoStop: { timerController.undoStop() }
            )
        case .resumeReading:
            ResumeReadingCard(
                bookmark: bookmark,
                usesCompactLayout: !isPad,
                onOpenReference: { _ in openContinueReading() },
                onStartReading: {
                    openBibleReference(book: "Genesis", chapter: 1, verse: 1)
                }
            )
        case .search:
            SearchHomeCard(onNeedsVisibility: { searchScrollRequest += 1 }) { result in
                openBibleReference(book: result.bookName, chapter: result.chapterNumber, verse: result.verseNumber)
            }
            .id(HomeCardID.search)
        case .today:
            HomeTodayCard(onStartPrayerTimer: startPrayerChallengeTimer)
        case .streaks:
            streaksCard
        case .bibleStats:
            BibleStatsCard(
                bibleVM: bibleVM,
                scenePhase: scenePhase,
                onOpenReadingStats: openReadingStats,
                onOpenGameStats: {
                    AppRouter.shared.open(.stats(.games))
                }
            )
        }
    }

    private var dashboardCards: [HomeCardID] {
        layoutOrder.filter {
            $0 != .verseOfDay && !hiddenCards.contains($0)
        }
    }

    private var showsMinimalHome: Bool {
        isPad
            && hiddenCards.contains(.verseOfDay)
            && dashboardCards.isEmpty
            && !bibleReaderVisible
    }

    @ViewBuilder
    private func homeHeader(usesDashboard: Bool) -> some View {
        let showsGoalSummary = !isStreaksCardShown(usesDashboard: usesDashboard)

        TitleCardView(
            isPad: isPad,
            goalMinutes: dailyGoalMinutes,
            todayReadingSeconds: bibleVM.todaySeconds,
            // Only computed when the header actually shows it.
            streak: showsGoalSummary ? StreakTracker.currentStreak : 0,
            showsGoalSummary: showsGoalSummary,
            onSearch: {
                coordinator.push(.search)
            },
            onFavorites: {
                AppRouter.shared.open(.favorites)
            },
            onOpenGoal: openReadingStats
        )
    }

    @ViewBuilder
    private var contextualHomeTip: some View {
        if contextualTipsEnabled {
            ContextualTipView(
                id: "home.customization",
                title: "Make Home your own",
                message: isPad
                    ? "Your visible cards fill this dashboard automatically. Choose and reorder them from Customize Home."
                    : "Choose which cards appear here and reorder them from Customize Home.",
                systemImage: "sparkles"
            )
        }
    }

    @ViewBuilder
    private var compactHomeContent: some View {
        homeHeader(usesDashboard: false)
            .frame(maxWidth: .infinity)
        contextualHomeTip
            .frame(maxWidth: .infinity)

        ForEach(layoutOrder.filter { !hiddenCards.contains($0) }) { cardID in
            card(for: cardID)
                .frame(maxWidth: .infinity)
        }

        if customizeButtonVisible {
            customizeHomeLink
        }
    }

    @ViewBuilder
    private func dashboardContent(width: CGFloat, availableHeight: CGFloat) -> some View {
        if showsMinimalHome {
            minimalHomeQuickActions
                .frame(minHeight: max(0, availableHeight - 96), alignment: .center)
        } else {
        let standardColumnSpacing: CGFloat = 16
        let columnWidth = (width - (standardColumnSpacing * 2)) / 3
        let mainCardsWidth = bibleReaderVisible ? (columnWidth * 2) + standardColumnSpacing : width
        let sidebarWidth = bibleReaderVisible ? columnWidth : 0
        let columnSpacing = bibleReaderVisible ? standardColumnSpacing : 0

        HomeDashboardColumns(
            columnSpacing: columnSpacing,
            mainWidth: mainCardsWidth,
            sidebarWidth: sidebarWidth
        ) {
            homeHeader(usesDashboard: true)
        } tip: {
            contextualHomeTip
        } main: {
            VStack(spacing: 10) {
                if !hiddenCards.contains(.verseOfDay) {
                    card(for: .verseOfDay)
                }

                if !dashboardCards.isEmpty {
                    HomeMasonryGrid(columnCount: 2, spacing: 10) {
                        ForEach(dashboardCards) { cardID in
                            card(for: cardID)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .animation(.snappy, value: dashboardCards)
                }
            }
        } sidebar: {
            if bibleReaderVisible {
                HomeBibleReaderCard(
                    verseOfDay: votdVM.verse,
                    onVerseAction: handleVerseActionFeedback
                )
            }
        }
        }
    }

    private var minimalHomeQuickActions: some View {
        HStack(alignment: .top, spacing: 16) {
            minimalHomeActionCard(
                title: "Books",
                message: "Browse the Bible",
                icon: "book.fill",
                tint: .blue,
                action: { switchTo(.bible) }
            )

            minimalHomeActionCard(
                title: "Continue Reading",
                message: bookmark.map { "\($0.bookName) \($0.chapterNumber):\($0.verseNumber)" } ?? "Start at Genesis 1",
                verseText: bookmark?.verseText,
                icon: "bookmark.fill",
                tint: .indigo,
                action: openContinueReading
            )

            minimalHomeActionCard(
                title: "Search",
                message: "Find a passage, word, or topic",
                icon: "magnifyingglass",
                tint: .teal,
                action: { coordinator.push(.search) }
            )
        }
    }

    private func minimalHomeActionCard(
        title: String,
        message: String,
        verseText: String? = nil,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HeroCard(title: title, subtitle: nil, icon: icon, tint: tint) {
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let verseText, !verseText.isEmpty {
                    Text("“\(verseText)”")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                Label("Open", systemImage: "arrow.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 104, weight: .bold))
                    .foregroundStyle(tint.opacity(0.12))
                    .padding(12)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityHint(message)
    }

    private func openContinueReading() {
        if let bookmark {
            openBibleReference(book: bookmark.bookName, chapter: bookmark.chapterNumber, verse: bookmark.verseNumber)
        } else {
            openBibleReference(book: "Genesis", chapter: 1, verse: 1)
        }
    }

    private var customizeHomeLink: some View {
        NavigationLink {
            HomeLayoutEditorView(
                order: $layoutOrder,
                hiddenSet: $hiddenCards,
                usesDashboard: isPad,
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

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let usesDashboard = availableWidth >= 700
            let horizontalPadding: CGFloat = usesDashboard ? 24 : 16
            let contentWidth = max(0, availableWidth - (horizontalPadding * 2))

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if usesDashboard {
                            dashboardContent(width: contentWidth, availableHeight: proxy.size.height)
                        } else {
                            compactHomeContent
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: searchScrollRequest) { _, _ in
                    Task {
                        // Let the keyboard finish appearing so the visible area is final.
                        try? await Task.sleep(for: .milliseconds(350))
                        withAnimation(.snappy) {
                            scrollProxy.scrollTo(HomeCardID.search, anchor: .top)
                        }
                    }
                }
            }
        }
        .background(AppBackgroundView(tab: .home))
        .navigationTitle("")
        .toolbar {
            if isPad {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HomeLayoutEditorView(
                            order: $layoutOrder,
                            hiddenSet: $hiddenCards,
                            usesDashboard: true,
                            onDone: saveHomeLayout,
                            onSaveFavorite: saveFavoriteLayout,
                            onResetToFavorite: applyFavoriteLayout,
                            hasFavorite: hasFavoriteLayout
                        )
                    } label: {
                        Label("Customize Home", systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .appToast(
            isPresented: $showCopyToast,
            symbol: verseActionToastSymbol,
            text: verseActionToastText,
            tint: verseActionToastTint
        )
        .onAppear {
            loadHomeLayout()
            bibleStore.ensureLoaded()

            // Verse-of-the-Day initial handling moved to VM
            votdVM.handleAppear()

            // Focus initial load
            focusVM.loadFromStorage()

            handleOpenPendingVerse()

            // Controllers
            timerController.onAppear()
            _ = timerController.handlePendingActionIfAny()

            // Initial load of Bible Stats. The view model intentionally waits for
            // appearance so construction and appearance do not refresh twice.
            bibleVM.refresh()

        }
        .onNotification(.homeLayoutChanged) {
            loadHomeLayout()
        }

        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                _ = timerController.handlePendingActionIfAny()
                handleOpenPendingVerse()
                bibleVM.refresh()
                votdVM.handleScenePhaseChange(newPhase)
                timerController.onSceneBecameActive()
            case .inactive, .background:
                timerController.onSceneBecameInactiveOrBackground()
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

        .sheet(isPresented: $showPrayerStudySheet) {
            PrayerStudyTimerSetupView(onStart: { minutes in
                timerController.start(minutes: minutes)
                showPrayerStudySheet = false
            })
            .presentationDetents([.medium, .large])
        }
        .alert(PrayerTimerController.finishedTitle, isPresented: Bindable(timerController).showFinishedAlert) {
            Button("Dismiss", role: .cancel) {
                timerController.stopFinishAlerts()
                timerController.showFinishedAlert = false
            }
        } message: {
            Text(PrayerTimerController.finishedMessage)
        }
    }

    /// Starts the prayer timer from a Today challenge and confirms it with a toast.
    private func startPrayerChallengeTimer(minutes: Int) {
        if timerController.isRunning {
            verseActionToastSymbol = "timer"
            verseActionToastText = "A prayer timer is already running"
            verseActionToastTint = .orange
        } else {
            timerController.start(minutes: minutes)
            verseActionToastSymbol = "timer"
            verseActionToastText = "Prayer timer started · \(minutes) min"
            verseActionToastTint = .green
        }

        withAnimation(.spring()) {
            showCopyToast = true
        }
    }

    private func handleVerseActionFeedback(_ feedback: VerseActionFeedback) {
        verseActionToastSymbol = feedback.toastSymbol
        verseActionToastText = feedback.toastText
        verseActionToastTint = feedback.toastTint

        withAnimation(.spring()) {
            showCopyToast = true
        }
    }

}

// Note: HeroCard, button styles,
// PrayerStudyTimerSetupView, and DebouncedWidgetReloader have been
// moved to their own files as part of UI extraction.
