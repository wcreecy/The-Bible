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
//     case bibleStats // Bible Stats (Top 5 by reading time)
//     var id: String { rawValue }
// }

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

    /// A landscape iPhone can report a regular horizontal size class, but the customizable
    /// three-column dashboard is designed for iPad's wider canvas.
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
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

    // MARK: - Dynamic body using saved layout

    @State private var votdVM = VerseOfDayViewModel()
    @State private var focusVM = FocusViewModel()
    @State private var bibleVM = HomeBibleStatsViewModel()

    // Bind Live Activities setting directly so Home tracks Settings in real time.
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    @State private var layoutOrder: [HomeCardID] = HomeLayoutStore.baselineOrder
    @State private var hiddenCards: Set<HomeCardID> = HomeLayoutStore.baselineHidden
    @State private var columns: HomeColumnLayout = HomeLayoutStore.baselineColumns
    @State private var hasFavoriteLayout: Bool = false
    /// Edit Home mode on the iPad dashboard: cards are arranged in place.
    @State private var isEditingLayout = false
    /// Whether the two-column dashboard (rather than the single column) is on screen.
    @State private var isShowingDashboard = false
    /// Incremented by the Search card to ask Home to scroll it into view while typing.
    @State private var searchScrollRequest = 0
    /// Set by the Welcome card's Make Home Yours step.
    @State private var showsSetupLayoutEditor = false
    @State private var showsEditHomeOnboardingCue = false
    @State private var isEditHomeCueDismissalEnabled = false
    @State private var editHomeCueCircleProgress: CGFloat = 0
    @State private var editHomeCueArrowProgress: CGFloat = 0
    @AppStorage("homeCustomizeButtonVisible") private var customizeButtonVisible = true
    @AppStorage("homeQuickSearchVisible") private var quickSearchVisible = true
    @AppStorage("homeBibleReaderVisible") private var bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible
    @AppStorage(HomeLayoutStore.keyBibleReaderColumn) private var bibleReaderColumn = HomeLayoutStore.defaultBibleReaderColumn

    private func loadHomeLayout() {
        let store = HomeLayoutStore()
        let loaded = store.load()
        layoutOrder = loaded.order
        hiddenCards = loaded.hidden
        columns = loaded.columns
        hasFavoriteLayout = store.hasFavorite
    }

    private func saveHomeLayout() {
        HomeLayoutStore().save(order: layoutOrder, hidden: hiddenCards, columns: columns)
    }

    private func showEditHomeOnboardingCue() {
        editHomeCueCircleProgress = 0
        editHomeCueArrowProgress = 0
        isEditHomeCueDismissalEnabled = false
        showsEditHomeOnboardingCue = true

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeOut(duration: 0.8)) {
                editHomeCueCircleProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(850))
            guard showsEditHomeOnboardingCue else { return }
            isEditHomeCueDismissalEnabled = true
            withAnimation(.easeOut(duration: 0.65)) {
                editHomeCueArrowProgress = 1
            }
        }
    }

    private func dismissEditHomeOnboardingCue(force: Bool = false) {
        guard showsEditHomeOnboardingCue, force || isEditHomeCueDismissalEnabled else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            showsEditHomeOnboardingCue = false
        }
    }

    private func beginEditingHomeLayout() {
        withAnimation(.snappy) {
            isEditingLayout = true
        }
        dismissEditHomeOnboardingCue(force: true)
    }

    /// Applies a column change from Edit Home and keeps the narrow-width order in step.
    private func updateColumns(_ change: (inout HomeColumnLayout) -> Void) {
        withAnimation(.snappy) {
            change(&columns)
            layoutOrder = columns.flatOrder
        }
        saveHomeLayout()
        Haptics.selection()
    }

    private func toggleCardHidden(_ id: HomeCardID) {
        withAnimation(.snappy) {
            if hiddenCards.contains(id) {
                hiddenCards.remove(id)
            } else {
                hiddenCards.insert(id)
            }
        }
        saveHomeLayout()
        Haptics.selection()
    }

    /// Hides a card from its own controls (such as the Welcome card's Hide); Customize Home can show it again.
    private func hideCard(_ id: HomeCardID) {
        guard !hiddenCards.contains(id) else { return }
        toggleCardHidden(id)
    }

    private func saveFavoriteLayout() {
        HomeLayoutStore().saveFavorite(
            order: layoutOrder,
            hidden: hiddenCards,
            columns: columns,
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
                icon: verseCardIcon,
                columnCount: isShowingDashboard ? columns.verseOfDayWidth.columnCount : 1
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
        case .savedVerses:
            SavedVersesHomeCardContainer(
                onOpenSavedVerses: { AppRouter.shared.open(.favorites) },
                onOpenVerse: { preview in
                    openBibleReference(
                        book: preview.bookName,
                        chapter: preview.chapterNumber,
                        verse: preview.verseNumber
                    )
                }
            )
        case .study:
            let target = studyTarget
            StudyHomeCard(bookName: target.bookName, chapterNumber: target.chapterNumber, source: target.source) {
                openBibleReference(book: target.bookName, chapter: target.chapterNumber, verse: target.verseNumber)
            }
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
        case .setup:
            SetupChecklistCard(
                onEditHome: {
                    if isPad && isShowingDashboard {
                        showEditHomeOnboardingCue()
                    } else {
                        showsSetupLayoutEditor = true
                    }
                },
                onDismiss: { hideCard(.setup) }
            )
        }
    }

    /// The chapter the Study card prepares for: the bookmarked one, so it matches Continue
    /// Reading, else the Verse of the Day's, else Genesis 1. Read opens at the bookmarked verse.
    private var studyTarget: (bookName: String, chapterNumber: Int, verseNumber: Int, source: StudyHomeCard.Source) {
        if let bookmark {
            return (bookmark.bookName, bookmark.chapterNumber, bookmark.verseNumber, .bookmark)
        }
        if let verse = votdVM.verse {
            return (verse.bookName, verse.chapterNumber, 1, .verseOfDay(title: verseCardTitle))
        }
        return ("Genesis", 1, 1, .startingPoint)
    }

    private var showsMinimalHome: Bool {
        isPad
            && hiddenCards.isSuperset(of: HomeCardID.allCases)
            && !bibleReaderVisible
    }

    @ViewBuilder
    private func homeHeader() -> some View {
        TitleCardView(
            isPad: isPad,
            goalMinutes: dailyGoalMinutes,
            todayReadingSeconds: bibleVM.todaySeconds,
            streak: StreakTracker.currentStreak,
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
                    ? "Tap Edit Home to arrange cards in any of the three columns, or choose them from Customize Home."
                    : "Choose which cards appear here and reorder them from Customize Home.",
                systemImage: "sparkles"
            )
        }
    }

    @ViewBuilder
    private var compactHomeContent: some View {
        homeHeader()
            .frame(maxWidth: .infinity)
        if quickSearchVisible {
            SearchHomeCard(
                presentation: .inline,
                onSelectResult: { result in
                    openBibleReference(
                        book: result.bookName,
                        chapter: result.chapterNumber,
                        verse: result.verseNumber
                    )
                }
            )
        }
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
        // While editing, the columns stay up even if every card is hidden, so cards can be shown again.
        if showsMinimalHome && !isEditingLayout {
            minimalHomeQuickActions
                .frame(minHeight: max(0, availableHeight - 96), alignment: .center)
        } else {
            homeHeader()

            if !isEditingLayout {
                if quickSearchVisible {
            SearchHomeCard(
                presentation: .inline,
                onSelectResult: { result in
                    openBibleReference(
                        book: result.bookName,
                        chapter: result.chapterNumber,
                        verse: result.verseNumber
                    )
                }
            )
        }
            }

            if isEditingLayout {
                editHomeHint
            } else {
                contextualHomeTip
            }

            HomeCardColumnsView(
                columns: columns,
                hiddenCards: hiddenCards,
                readerColumn: bibleReaderVisible ? bibleReaderColumn : nil,
                isEditing: isEditingLayout,
                width: width,
                columnSpacing: 16,
                cardSpacing: 10,
                onMoveAcross: { id, offset in
                    updateColumns { $0.moveAcross(id, by: offset) }
                },
                onMoveWithinColumn: { id, offset in
                    updateColumns { $0.move(id, by: offset) }
                },
                onToggleHidden: toggleCardHidden,
                onSetVerseOfDayColumnCount: { count in
                    updateColumns {
                        $0.setVerseOfDayColumnCount(count, readerColumn: bibleReaderVisible ? bibleReaderColumn : nil)
                    }
                }
            ) { cardID in
                card(for: cardID)
            } reader: {
                // While editing, the panel moves down so its controls sit above its title.
                HomeBibleReaderCard(
                    verseOfDay: votdVM.verse,
                    onVerseAction: handleVerseActionFeedback
                )
                .padding(.top, isEditingLayout ? HomeCardEditChrome.barHeight : 0)
                .overlay(alignment: .top) {
                    if isEditingLayout {
                        bibleReaderEditControls
                    }
                }
            }
        }
    }

    private var editHomeHint: some View {
        Label {
            Text("Use the arrows to move cards up, down, left, or right. Tap – to hide a card, or \(Image(systemName: "arrow.left.and.right")) to widen Verse of the Day. Tap Done when you're finished.")
        } icon: {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// Edit Home controls for the Today's Reading panel: move it to another column or hide it.
    private var bibleReaderEditControls: some View {
        HStack(spacing: 8) {
            HomeEditControlButton(
                systemImage: "arrow.left",
                label: "Move Today's Reading left",
                disabled: bibleReaderColumn.neighbor(by: -1) == nil
            ) {
                moveBibleReader(by: -1)
            }

            Button {
                withAnimation(.snappy) { bibleReaderVisible = false }
                Haptics.selection()
            } label: {
                Label("Hide", systemImage: "eye.slash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Hide Today's Reading")

            HomeEditControlButton(
                systemImage: "arrow.right",
                label: "Move Today's Reading right",
                disabled: bibleReaderColumn.neighbor(by: 1) == nil
            ) {
                moveBibleReader(by: 1)
            }
        }
        .frame(height: HomeCardEditChrome.barHeight)
    }

    /// Moves the Today's Reading panel to the neighboring column; cards there stay below it.
    private func moveBibleReader(by offset: Int) {
        guard let destination = bibleReaderColumn.neighbor(by: offset) else { return }
        withAnimation(.snappy) { bibleReaderColumn = destination }
        Haptics.selection()
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

    private func layoutEditor(usesDashboard: Bool) -> some View {
        HomeLayoutEditorView(
            order: $layoutOrder,
            hiddenSet: $hiddenCards,
            columns: $columns,
            usesDashboard: usesDashboard,
            onDone: saveHomeLayout,
            onSaveFavorite: saveFavoriteLayout,
            onResetToFavorite: applyFavoriteLayout,
            hasFavorite: hasFavoriteLayout
        )
    }

    private var customizeHomeLink: some View {
        NavigationLink {
            layoutEditor(usesDashboard: isPad)
        } label: {
            Label("Customize Home", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
    }

    var body: some View {
        GeometryReader { proxy in
            let usesDashboard = isPad && proxy.size.width >= 700
            let horizontalPadding: CGFloat = usesDashboard ? 24 : 16
            let contentWidth = max(0, proxy.size.width - (horizontalPadding * 2))

            HomeScrollContent(
                usesDashboard: usesDashboard,
                contentWidth: contentWidth,
                availableHeight: proxy.size.height,
                horizontalPadding: horizontalPadding,
                searchScrollRequest: searchScrollRequest,
                dismissCue: { dismissEditHomeOnboardingCue() },
                onSearchScroll: { scrollProxy in
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        withAnimation(.snappy) {
                            scrollProxy.scrollTo(HomeCardID.search, anchor: .top)
                        }
                    }
                },
                dashboard: {
                    dashboardContent(width: contentWidth, availableHeight: proxy.size.height)
                },
                compact: {
                    compactHomeContent
                }
            )
        }
        .onGeometryChange(for: Bool.self) { proxy in
            isPad && proxy.size.width >= 700
        } action: { showsDashboard in
            isShowingDashboard = showsDashboard
            // Edit Home arranges the dashboard; leave it if the dashboard goes away.
            if !showsDashboard {
                isEditingLayout = false
                dismissEditHomeOnboardingCue(force: true)
            }
        }
        .background(AppBackgroundView(tab: .home))
        .accessibilityIdentifier("homeView")
        .navigationTitle("")
        .toolbar {
            if isPad && isShowingDashboard {
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditingLayout {
                        Button("Done", systemImage: "checkmark", role: .confirm) {
                            withAnimation(.snappy) { isEditingLayout = false }
                        }
                        .accessibilityIdentifier("homeEditDoneButton")
                    } else {
                        EditHomeToolbarButton(
                            showsCue: showsEditHomeOnboardingCue,
                            circleProgress: editHomeCueCircleProgress,
                            arrowProgress: editHomeCueArrowProgress,
                            action: beginEditingHomeLayout
                        )
                }
            }
            }
            if isPad && !isEditingLayout {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        layoutEditor(usesDashboard: true)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Customize Home")
                }
            }
        }
        .navigationDestination(isPresented: $showsSetupLayoutEditor) {
            layoutEditor(usesDashboard: isPad)
        }
        .appToast(
            isPresented: $showCopyToast,
            symbol: verseActionToastSymbol,
            text: verseActionToastText,
            tint: verseActionToastTint
        )
        .onAppear {
            AppPerformance.measure("HomeCardPreparation") {
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

            // The stats card can populate just after the initial frame. Keeping the
            // aggregation out of this appearance pass makes Home immediately tappable.
            Task { @MainActor in
                await Task.yield()
                bibleVM.refresh()
            }
            }
        }
        .onNotification(.homeLayoutChanged) {
            loadHomeLayout()
        }
        .onDisappear {
            isEditingLayout = false
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
        .modifier(PrayerTimerFinishedAlert(timerController: timerController))
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

/// Keeps saved-verse queries and preview construction out of the large Home view's
/// invalidation boundary. Changes to saved verses now update this card alone.
private struct SavedVersesHomeCardContainer: View {
    @Query private var favorites: [Favorite]
    @Query(filter: #Predicate<VerseNote> { $0.highlightColor != "" }) private var highlights: [VerseNote]
    @AppStorage("homeSavedVersePinID") private var savedVersePinID = ""
    @AppStorage("homeSavedVersePinDay") private var savedVersePinDay = 0
    @State private var previewOffset = 0

    let onOpenSavedVerses: () -> Void
    let onOpenVerse: (SavedVerseHomePreview) -> Void

    private var previews: [SavedVerseHomePreview] {
        favorites.map { favorite in
            SavedVerseHomePreview(
                reference: "\(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)",
                text: favorite.verseText,
                kind: .favorite,
                date: favorite.createdAt,
                bookName: favorite.bookName,
                chapterNumber: favorite.chapterNumber,
                verseNumber: favorite.verseNumber,
                highlightColor: nil
            )
        } + highlights.map { highlight in
            SavedVerseHomePreview(
                reference: highlight.reference,
                text: highlight.verseText,
                kind: .highlight,
                date: highlight.createdAt ?? highlight.updatedAt ?? .distantPast,
                bookName: highlight.bookName,
                chapterNumber: highlight.chapterNumber,
                verseNumber: highlight.verseNumber,
                highlightColor: VerseHighlightColor(rawValue: highlight.highlightColor)
            )
        }
    }

    private var pinnedPreview: SavedVerseHomePreview.DailyPin? {
        savedVersePinID.isEmpty ? nil : .init(id: savedVersePinID, day: savedVersePinDay)
    }

    var body: some View {
        let preview = SavedVerseHomePreview.dailyPreview(
            from: previews,
            rotationOffset: previewOffset,
            pinned: pinnedPreview
        )

        SavedVersesHomeCard(
            preview: preview,
            favoriteCount: favorites.count,
            highlightCount: highlights.count,
            onOpenSavedVerses: onOpenSavedVerses,
            onRefresh: {
                savedVersePinID = ""
                previewOffset += 1
            },
            onOpenVerse: onOpenVerse
        )
        .onChange(of: "\(preview?.pinID ?? "")|\(SavedVerseHomePreview.dayIndex(for: .now))", initial: true) {
            pin(preview)
        }
    }

    private func pin(_ preview: SavedVerseHomePreview?) {
        let day = SavedVerseHomePreview.dayIndex(for: .now)
        guard let preview, preview.pinID != savedVersePinID || day != savedVersePinDay else { return }
        savedVersePinID = preview.pinID
        savedVersePinDay = day
    }
}

private struct PrayerTimerFinishedAlert: ViewModifier {
    let timerController: PrayerTimerController

    func body(content: Content) -> some View {
        content
            .alert(
                PrayerTimerController.finishedTitle,
                isPresented: Bindable(timerController).showFinishedAlert
            ) {
                Button("Dismiss", role: .cancel) {
                    timerController.stopFinishAlerts()
                    timerController.showFinishedAlert = false
                }
            } message: {
                Text(PrayerTimerController.finishedMessage)
            }
    }
}

private struct EditHomeToolbarButton: View {
    let showsCue: Bool
    let circleProgress: CGFloat
    let arrowProgress: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsCue {
                    EditHomeToolbarArrow()
                        .trim(from: 0, to: arrowProgress)
                        .stroke(
                            .red,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 34, height: 22)
                        .accessibilityHidden(true)
                }
                Image(systemName: "square.grid.2x2")
                    .overlay {
                        Circle()
                            .trim(from: 0, to: circleProgress)
                            .stroke(
                                .red,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .padding(-8)
                            .opacity(showsCue ? 1 : 0)
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }
            }
        }
        .accessibilityLabel("Edit Home")
        .accessibilityIdentifier("homeEditButton")
    }
}

private struct HomeScrollContent<Dashboard: View, Compact: View>: View {
    let usesDashboard: Bool
    let contentWidth: CGFloat
    let availableHeight: CGFloat
    let horizontalPadding: CGFloat
    let searchScrollRequest: Int
    let dismissCue: () -> Void
    let onSearchScroll: (ScrollViewProxy) -> Void
    private let dashboard: () -> Dashboard
    private let compact: () -> Compact

    init(
        usesDashboard: Bool,
        contentWidth: CGFloat,
        availableHeight: CGFloat,
        horizontalPadding: CGFloat,
        searchScrollRequest: Int,
        dismissCue: @escaping () -> Void,
        onSearchScroll: @escaping (ScrollViewProxy) -> Void,
        @ViewBuilder dashboard: @escaping () -> Dashboard,
        @ViewBuilder compact: @escaping () -> Compact
    ) {
        self.usesDashboard = usesDashboard
        self.contentWidth = contentWidth
        self.availableHeight = availableHeight
        self.horizontalPadding = horizontalPadding
        self.searchScrollRequest = searchScrollRequest
        self.dismissCue = dismissCue
        self.onSearchScroll = onSearchScroll
        self.dashboard = dashboard
        self.compact = compact
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 16) {
                    if usesDashboard {
                        dashboard()
                    } else {
                        compact()
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .tabBarContentClearance()
            .simultaneousGesture(DragGesture(minimumDistance: 1).onChanged { _ in dismissCue() })
            .simultaneousGesture(TapGesture().onEnded { dismissCue() })
            .onChange(of: searchScrollRequest) { _, _ in onSearchScroll(scrollProxy) }
        }
    }
}

/// A short arrow that ends immediately beside the highlighted Edit Home grid icon.
private struct EditHomeToolbarArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.maxX - 2, y: rect.midY)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 8, y: tip.y - 6))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 8, y: tip.y + 6))

        return path
    }
}

// Note: HeroCard, button styles,
// PrayerStudyTimerSetupView, and DebouncedWidgetReloader have been
// moved to their own files as part of UI extraction.
