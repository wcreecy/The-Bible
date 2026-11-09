import SwiftUI
import SwiftData
import UIKit
import Foundation

// Card arrangement state lives in HomeLayoutModel.swift; the Edit Home hint, reader edit
// controls, and minimal-home actions live in HomeDashboardChrome.swift.
struct HomeView: View {
    @State private var showPrayerStudySheet: Bool = false
    @State private var showPrayerTimerSheet: Bool = false

    private var timerController = PrayerTimerController.shared

    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    @Environment(NavigationCoordinator.self) private var coordinator

    @State private var showCopyToast: Bool = false
    @State private var verseActionToastSymbol: String = "doc.on.doc"
    @State private var verseActionToastText: String = "Copied to Clipboard"
    @State private var verseActionToastTint: Color = .accentColor

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    @Query(sort: [SortDescriptor(\Favorite.createdAt, order: .reverse)]) private var favorites: [Favorite]

    #if DEBUG
    @AppStorage(DeveloperTools.resumeReadingPreviewKey) private var resumeReadingPreview = DeveloperTools.ResumeReadingPreview.actual.rawValue
    #endif

    /// The verse the reader bookmarked; the single source for Continue Reading.
    /// (The automatic last-read position only drives where the Bible tab opens.)
    private var bookmark: Bookmark? {
        bookmarks.first
    }

    @MainActor private var resumeReadingPoint: ResumeReadingCard.ReadingPoint? {
        #if DEBUG
        if let preview = DeveloperTools.ResumeReadingPreview(rawValue: resumeReadingPreview),
           let previewDate = preview.date {
            return ResumeReadingCard.ReadingPoint(
                bookName: "Matthew",
                chapterNumber: 6,
                verseNumber: 9,
                verseText: "After this manner therefore pray ye: Our Father which art in heaven, Hallowed be thy name.",
                savedAt: previewDate
            )
        }
        #endif
        return bookmark.map(ResumeReadingCard.ReadingPoint.init)
    }

    // Verse-of-the-Day: configurable times and scheduler (delegated to VM, keep keys observed)
    @AppStorage("votdRefreshFrequency") private var votdRefreshFrequency: String = VOTDRefreshFrequency.custom.rawValue
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0

    // Bible store for async/on-demand loading
    private var bibleStore = BibleStore.shared

    @State private var votdVM = VerseOfDayViewModel()
    @State private var focusVM = FocusViewModel()
    @State private var bibleVM = HomeBibleStatsViewModel()

    // Bind Live Activities setting directly so Home tracks Settings in real time.
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    /// Standard Live Activities move to the Dynamic Island after the app leaves the
    /// foreground. Keep the same timer visible in Home while the app is active.
    private var shouldShowPrayerTimerBanner: Bool {
        timerController.isRunning && (isPad || !liveActivitiesEnabled || scenePhase == .active)
    }

    @State private var layout = HomeLayoutModel()
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

    // MARK: - Body
    // Built in stages (layout and toolbar, presentations, lifecycle) so each stage is
    // type-checked on its own instead of as one long modifier chain.

    var body: some View {
        homeWithPresentations
            .onAppear {
                AppPerformance.measure("HomeCardPreparation") {
                    layout.load()
                    bibleStore.ensureLoaded()

                    // Verse-of-the-Day initial handling moved to VM
                    votdVM.handleAppear(favorites: favorites)

                    // Focus initial load
                    focusVM.loadFromStorage()

                    handleOpenPendingVerse()

                    // Controllers
                    timerController.onAppear()

                    // The stats card can populate just after the initial frame. Keeping the
                    // aggregation out of this appearance pass makes Home immediately tappable.
                    Task { @MainActor in
                        await Task.yield()
                        AppPerformance.measure("HomeStatsRefresh") {
                            bibleVM.refresh()
                        }
                    }
                }
            }
            .onNotification(.homeLayoutChanged) {
                layout.load()
            }
            .onDisappear {
                isEditingLayout = false
                votdVM.clearManualRefreshHistory()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    handleOpenPendingVerse()
                    AppPerformance.measure("HomeStatsRefresh") {
                        bibleVM.refresh()
                    }
                    votdVM.handleScenePhaseChange(newPhase, favorites: favorites)
                    timerController.onSceneBecameActive()
                case .inactive, .background:
                    timerController.onSceneBecameInactiveOrBackground()
                @unknown default:
                    break
                }
            }
            // Score the Bible for the Verse of the Day as soon as it has loaded.
            .onChange(of: bibleStore.isReady, initial: true) { _, isReady in
                if isReady { votdVM.warmSelectionPool() }
            }
            .onChange(of: bibleStore.translation) { _, _ in
                votdVM.translationChanged()
            }
            // Forward VOTD schedule changes to the VM
            .onChange(of: votdRefreshFrequency) { _, _ in votdVM.refreshScheduleChanged() }
            .onChange(of: votdRefresh1Hour) { _, _ in votdVM.refreshScheduleChanged() }
            .onChange(of: votdRefresh1Minute) { _, _ in votdVM.refreshScheduleChanged() }
            .onChange(of: votdRefresh2Hour) { _, _ in votdVM.refreshScheduleChanged() }
            .onChange(of: votdRefresh2Minute) { _, _ in votdVM.refreshScheduleChanged() }
            .onChange(of: favorites.count) { _, _ in votdVM.updateFavorites(favorites) }
    }

    private var homeLayout: some View {
        GeometryReader { proxy in
            // Three narrow dashboard columns cannot preserve readable card content at
            // accessibility text sizes, so use the already-supported single-column flow.
            let usesDashboard = isPad && proxy.size.width >= 700 && !dynamicTypeSize.isAccessibilitySize
            let horizontalPadding: CGFloat = usesDashboard ? 24 : 16
            let contentWidth = max(0, proxy.size.width - (horizontalPadding * 2))

            HomeScrollContent(
                usesDashboard: usesDashboard,
                contentWidth: contentWidth,
                availableHeight: proxy.size.height,
                horizontalPadding: horizontalPadding,
                searchScrollRequest: searchScrollRequest,
                dismissCue: { dismissEditHomeOnboardingCue() },
                dashboard: {
                    dashboardContent(width: contentWidth, availableHeight: proxy.size.height)
                        .accessibilityIdentifier("homeDashboardContent")
                },
                compact: {
                    compactHomeContent
                        .accessibilityIdentifier("homeCompactContent")
                }
            )
        }
        .onGeometryChange(for: Bool.self) { proxy in
            isPad && proxy.size.width >= 700 && !dynamicTypeSize.isAccessibilitySize
        } action: { showsDashboard in
            isShowingDashboard = showsDashboard
            // Edit Home arranges the dashboard; leave it if the dashboard goes away.
            if !showsDashboard {
                isEditingLayout = false
                dismissEditHomeOnboardingCue(force: true)
            }
        }
        .background(AppBackgroundView(tab: .home))
        .safeAreaInset(edge: .top, spacing: 0) {
            if shouldShowPrayerTimerBanner {
                prayerTimerBanner
            }
        }
        .accessibilityIdentifier("homeView")
        .navigationTitle("")
        .toolbar { homeToolbar }
    }

    private var homeWithPresentations: some View {
        homeLayout
            .navigationDestination(isPresented: $showsSetupLayoutEditor) {
                layoutEditor(usesDashboard: isPad)
            }
            .appToast(
                isPresented: $showCopyToast,
                symbol: verseActionToastSymbol,
                text: verseActionToastText,
                tint: verseActionToastTint
            )
            .sheet(isPresented: $showPrayerStudySheet) {
                PrayerStudyTimerSetupView(onStart: { minutes in
                    timerController.start(minutes: minutes)
                    showPrayerStudySheet = false
                })
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPrayerTimerSheet) {
                PrayerTimerDetailSheet(
                    timerController: timerController,
                    verseOfDay: votdVM.verse
                )
            }
            .modifier(PrayerTimerFinishedAlert(timerController: timerController))
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
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
    }

    private var prayerTimerBanner: some View {
        ActivePrayerTimerBanner(
            kind: timerController.kind,
            isPaused: timerController.isPaused,
            remainingSeconds: timerController.remainingSeconds
        ) {
            Haptics.selection()
            showPrayerTimerSheet = true
        }
        .padding(.horizontal, isPad ? 24 : 16)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var compactHomeContent: some View {
        homeHeader()
            .frame(maxWidth: .infinity)
        if quickSearchVisible {
            quickSearchCard
        }
        contextualHomeTip
            .frame(maxWidth: .infinity)

        ForEach(layout.visibleOrder) { cardID in
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
            HomeMinimalQuickActions(
                bookmark: bookmark,
                onOpenBooks: { switchTo(.bible) },
                onContinueReading: openContinueReading,
                onSearch: { coordinator.push(.search) }
            )
            .frame(minHeight: max(0, availableHeight - 96), alignment: .center)
        } else {
            homeHeader()

            if !isEditingLayout && quickSearchVisible {
                quickSearchCard
            }

            if isEditingLayout {
                HomeEditHint()
            } else {
                contextualHomeTip
            }

            dashboardColumns(width: width)
        }
    }

    private func dashboardColumns(width: CGFloat) -> some View {
        HomeCardColumnsView(
            columns: layout.columns,
            hiddenCards: layout.hidden,
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
                    HomeBibleReaderEditControls(
                        column: $bibleReaderColumn,
                        isVisible: $bibleReaderVisible
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func card(for id: HomeCardID) -> some View {
        switch id {
        case .verseOfDay:
            verseOfDayCard
        case .dailyFocus:
            DailyFocusCard(
                focus: focusVM,
                liveActivitiesEnabled: liveActivitiesEnabled,
                onEnableLiveActivities: {
                    AppRouter.shared.open(.settings)
                }
            )
        case .timer:
            HomePrayerTimerCard(
                timerController: timerController,
                verseOfDay: votdVM.verse,
                onOpenSetup: {
                    Haptics.selection()
                    showPrayerStudySheet = true
                }
            )
        case .resumeReading:
            ResumeReadingCard(
                readingPoint: resumeReadingPoint,
                usesCompactLayout: !isPad,
                onOpenReference: { readingPoint in
                    openBibleReference(
                        book: readingPoint.bookName,
                        chapter: readingPoint.chapterNumber,
                        verse: readingPoint.verseNumber
                    )
                },
                onStartReading: {
                    openBibleReference(book: "Genesis", chapter: 1, verse: 1)
                },
                onChoosePassage: { bookName, chapterNumber, verseNumber in
                    openBibleReference(book: bookName, chapter: chapterNumber, verse: verseNumber)
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
            studyCard
        case .search:
            SearchHomeCard(
                onNeedsVisibility: { searchScrollRequest += 1 },
                onOpenSearch: { coordinator.push(.search) }
            ) { result in
                openBibleReference(book: result.bookName, chapter: result.chapterNumber, verse: result.verseNumber)
            }
            .id(HomeCardID.search)
        case .today:
            HomeTodayCard(onStartPrayerTimer: startPrayerChallengeTimer)
        case .streaks:
            StreaksCard(
                onOpenStats: openReadingStats,
                onReadNow: openContinueReading
            )
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

    private var verseOfDayCard: some View {
        VerseOfDayCard(
            verseOfDay: $votdVM.verse,
            verseOfDayPaused: $votdVM.paused,
            isBibleStoreReady: bibleStore.isReady,
            nextRefreshDescription: votdVM.nextRefreshDescription,
            canUndoRefresh: votdVM.canUndoManualRefresh,
            onRefresh: refreshVerseOfDay,
            onUndoRefresh: { withAnimation(.easeInOut(duration: 0.25)) { votdVM.undoManualRefresh() } },
            onVerseActionFeedback: handleVerseActionFeedback,
            onOpenReader: { verse in
                openInBibleTab(verse)
            },
            onTogglePaused: {
                votdVM.togglePaused()
            },
            title: verseCardTitle,
            icon: verseCardIcon,
            columnCount: isShowingDashboard ? layout.columns.verseOfDayWidth.columnCount : 1
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            guard let verse = votdVM.verse else { return }
            openInBibleTab(verse)
        }
    }

    private var studyCard: some View {
        let target = studyTarget
        return StudyHomeCard(
            bookName: target.bookName,
            chapterNumber: target.chapterNumber,
            startVerseNumber: target.verseNumber,
            verseText: target.verseText,
            source: target.source
        ) {
            openBibleReference(book: target.bookName, chapter: target.chapterNumber, verse: target.verseNumber)
        }
    }

    /// The inline search field above the cards, in both the compact and dashboard layouts.
    private var quickSearchCard: some View {
        SearchHomeCard(
            presentation: .inline,
            onOpenSearch: { coordinator.push(.search) },
            onSelectResult: { result in
                openBibleReference(
                    book: result.bookName,
                    chapter: result.chapterNumber,
                    verse: result.verseNumber
                )
            }
        )
    }

    /// The chapter the Study card prepares for: the bookmarked one, so it matches Continue
    /// Reading, else the Verse of the Day's, else Genesis 1. Read opens at the bookmarked verse.
    private var studyTarget: (
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int,
        verseText: String?,
        source: StudyHomeCard.Source
    ) {
        if let bookmark {
            return (
                bookmark.bookName,
                bookmark.chapterNumber,
                bookmark.verseNumber,
                bookmark.verseText,
                .bookmark
            )
        }
        if let verse = votdVM.verse {
            return (
                verse.bookName,
                verse.chapterNumber,
                verse.verseNumber,
                verse.verseText,
                .verseOfDay(title: verseCardTitle)
            )
        }
        return ("Genesis", 1, 1, nil, .startingPoint)
    }

    private var showsMinimalHome: Bool {
        isPad && layout.hidesEveryCard && !bibleReaderVisible
    }

    @ViewBuilder
    private func homeHeader() -> some View {
        TitleCardView(isPad: isPad)
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

    private func layoutEditor(usesDashboard: Bool) -> some View {
        @Bindable var layout = layout

        return HomeLayoutEditorView(
            order: $layout.order,
            hiddenSet: $layout.hidden,
            columns: $layout.columns,
            usesDashboard: usesDashboard,
            onDone: { layout.save() },
            onSaveFavorite: { layout.saveFavorite(bibleReaderVisible: bibleReaderVisible) },
            onResetToFavorite: { layout.applyFavorite() }
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

    // MARK: - Edit Home

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
            layout.updateColumns(change)
        }
        Haptics.selection()
    }

    private func toggleCardHidden(_ id: HomeCardID) {
        withAnimation(.snappy) {
            layout.toggleHidden(id)
        }
        Haptics.selection()
    }

    /// Hides a card from its own controls (such as the Welcome card's Hide); Customize Home can show it again.
    private func hideCard(_ id: HomeCardID) {
        guard !layout.hidden.contains(id) else { return }
        toggleCardHidden(id)
    }

    // MARK: - Navigation

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

    private func openReadingStats() {
        AppRouter.shared.open(.stats(.reading))
    }

    private func switchTo(_ tab: AppTab) {
        AppRouter.shared.open(.tab(tab))
    }

    private func openContinueReading() {
        if let bookmark {
            openBibleReference(book: bookmark.bookName, chapter: bookmark.chapterNumber, verse: bookmark.verseNumber)
        } else {
            openBibleReference(book: "Genesis", chapter: 1, verse: 1)
        }
    }

    // MARK: - Actions

    /// Starts the prayer timer from a Today challenge and confirms it with a toast.
    private func startPrayerChallengeTimer(minutes: Int) {
        if timerController.isRunning {
            verseActionToastSymbol = "timer"
            verseActionToastText = "A prayer timer is already running"
            verseActionToastTint = .orange
        } else {
            // The challenge is to pray, so it always starts a prayer session.
            timerController.start(minutes: minutes, kind: .prayer)
            verseActionToastSymbol = "timer"
            verseActionToastText = "Prayer timer started · \(minutes) min"
            verseActionToastTint = .green
        }

        withAnimation(.spring()) {
            showCopyToast = true
        }
    }

    /// Refreshes the Verse of the Day. A pinned verse doesn't refresh, so say why.
    private func refreshVerseOfDay() {
        guard !votdVM.paused else {
            Haptics.warning()
            verseActionToastSymbol = "pin.fill"
            verseActionToastText = "Unpin the verse to refresh it"
            verseActionToastTint = .orange
            withAnimation(.spring()) {
                showCopyToast = true
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            votdVM.refreshNow(favorites: favorites)
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
