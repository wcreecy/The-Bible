//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import CoreData
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

// Tab reselection lives in TabReselection.swift, game time in GamePlayTimeSession.swift,
// and widget/custom URL parsing in AppDeepLink.swift.
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.persistenceStoreMode) private var persistenceStoreMode
    // Separate coordinators per tab to avoid path leakage/corruption
    @State private var homeCoordinator = NavigationCoordinator()
    @State private var bibleCoordinator = NavigationCoordinator()
    private var bibleStore = BibleStore.shared
    @State private var notesPath = NavigationPath()
    @State private var gamesPath = NavigationPath()
    @State private var morePath: [MoreDestination] = []

    @State private var selectedTab: AppTab = .home
    @State private var tabViewRecoveryID = 0
    @State private var bibleSearchRequestID: Int = 0
    @State private var bibleStudyRequestID: Int = 0
    @State private var bibleStudyDestination: AppRouter.StudyDestination?
    @State private var launchBibleLocation: BibleReaderLocation?
    
    @AppStorage(AppStorageKey.colorSchemePreference) private var colorSchemePreferenceRaw: String = ColorSchemePreference.system.rawValue
    
    // One-time cleanup flag for deprecated app time keys
    @AppStorage(AppStorageKey.didCleanupAppTimeKeys) private var didCleanupAppTimeKeys: Bool = false
    // One-time cleanup for deprecated keepScreenOn setting
    @AppStorage(AppStorageKey.didCleanupKeepScreenOnKey) private var didCleanupKeepScreenOnKey: Bool = false

    @Environment(\.scenePhase) private var scenePhase

    // Game time is counted only while a game screen is open in the foreground.
    @State private var gameTime = GamePlayTimeSession()

    private var preferredScheme: ColorScheme? { (ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme }
    private var usesWideLayout: Bool { horizontalSizeClass == .regular }

    // Track previous tab to detect leaving Games
    @State private var previousTab: AppTab = .home
    @State private var didOpenLaunchBible = false

    private let router = AppRouter.shared
    /// The last router request performed, so none is handled twice.
    @State private var handledRequestID: UUID?
    @State private var deduplicationTask: Task<Void, Never>?

    init() {
        let launchTab = LaunchTabPreference.currentDeviceSelection()
        _selectedTab = State(initialValue: launchTab)
        _previousTab = State(initialValue: launchTab)
    }
    
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            HomeTabView(path: $homeCoordinator.path, coordinator: homeCoordinator)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            if usesWideLayout {
                BibleSplitView(
                    searchRequestID: bibleSearchRequestID,
                    studyRequestID: bibleStudyRequestID,
                    studyDestination: bibleStudyDestination,
                    initialReaderLocation: launchBibleLocation
                )
                    .tabItem { Label("Bible", systemImage: "book") }
                    .tag(AppTab.bible)
            } else {
                NavigationStack(path: $bibleCoordinator.path) {
                    BooksView(books: bibleStore.books)
                        .appDestinations(coordinator: bibleCoordinator)
                }
                .environment(bibleCoordinator)
                .tabItem { Label("Bible", systemImage: "book") }
                .tag(AppTab.bible)
            }

            NavigationStack(path: $notesPath) {
                NotesView()
            }
            .tabItem { Label("Notes", systemImage: "highlighter") }
            .tag(AppTab.notes)

            NavigationStack(path: $gamesPath) {
                GamesView(path: $gamesPath)
            }
            .tabItem { Label("Games", systemImage: "gamecontroller") }
            .tag(AppTab.games)

            NavigationStack(path: $morePath) {
                MoreView()
            }
            .tabItem { Label("More", systemImage: "ellipsis.circle") }
            .tag(AppTab.more)
        }
        .id(tabViewRecoveryID)
        // On iPad, TabView renders the app's top-level navigation as a floating
        // top tab bar. Keep it visible while a nested searchable view focuses
        // its field and presents the keyboard.
        .toolbarVisibility(.visible, for: .tabBar)
        .background {
            TabReselectionObserver { tabIndex in
                guard let tab = AppTab(rawValue: tabIndex), tab == selectedTab else { return }
                handleTabReselection(tab)
            }
            // Lets study and game time stop counting while the app sits untouched.
            UserActivityCaptureView()
        }
    }

    var body: some View {
        tabs
        .safeAreaInset(edge: .top, spacing: 0) {
            StoreFallbackBanner(mode: persistenceStoreMode)
        }
        .background(AppBackgroundView(tab: selectedTab))
        // Apply your preferred color scheme even on the Settings tab so it updates in place.
        .preferredColorScheme(preferredScheme)
        .onAppear { handleAppear() }
        .onChange(of: selectedTab) { oldValue, newValue in
            handleSelectedTabChange(from: oldValue, to: newValue)
        }
        .onOpenURL { url in handleOpenURL(url) }
        // Every app-wide navigation request is performed here.
        .onChange(of: router.latest) { _, request in
            if let request { handle(request) }
        }
        .onChange(of: scenePhase) { _, newValue in
            handleScenePhaseChange(newValue)
        }
        .onChange(of: gamesPath) { _, _ in
            updateGameTimeTracking()
            updateMindfulMinutesTracking()
        }
        // CloudKit imports can deliver a favorite or note for a verse that already has
        // one from this device; resolve those duplicates after each import settles.
        .onNotification(.NSPersistentStoreRemoteChange) {
            scheduleDeduplication()
        }
    }

    /// Runs the deduplicator 2 seconds after the last remote change in a burst.
    private func scheduleDeduplication() {
        deduplicationTask?.cancel()
        deduplicationTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            SwiftDataDeduplicator.run(in: modelContext)
        }
    }

    // MARK: - Body event handlers
    // Kept out of `body` so the modifier chain type-checks quickly.

    private func handleAppear() {
        // The only place iCloud key-value sync starts; stats pull and merge on launch.
        iCloudSyncCoordinator.shared.start()
        clearAppIconBadge()
        ReadingSessionsStore.shared.prewarm()

        // One-time cleanup of deprecated keys
        UserDefaults.standard.removeObject(forKey: AppStorageKey.fontFamilyPreference)

        if !didCleanupAppTimeKeys {
            UserDefaults.standard.removeObject(forKey: AppStorageKey.appTotalActiveSeconds)
            UserDefaults.standard.removeObject(forKey: AppStorageKey.appActiveStart)
            didCleanupAppTimeKeys = true
        }
        if !didCleanupKeepScreenOnKey {
            UserDefaults.standard.removeObject(forKey: AppStorageKey.keepScreenOn)
            didCleanupKeepScreenOnKey = true
        }

        bibleStore.ensureLoaded()
        // Seeds the single reading position from the records it replaced (runs once).
        ReadingPositionStore.shared.migrateIfNeeded(modelContext: modelContext)
        Bookmark.mirrorToWidget(in: modelContext)
        openBibleReaderAtLaunchIfNeeded()
        scheduleInitialDataMaintenance()

        Task.detached {
            _ = await BibleReferenceLinker.linkify("")
        }

        Task { @MainActor in
            await Task.yield()
            if selectedTab == .home {
                ensureSavedFocusLiveActivityIfNeeded()
            }
        }

        UserDefaults.standard.removeObject(forKey: AppStorageKey.lastBackgroundedAt)
        updateGameTimeTracking()
        updateMindfulMinutesTracking()

        // Initialize previousTab at launch
        previousTab = selectedTab
        handlePendingVerseOfDayNotification()

        // A request made before this view existed (for example a notification tapped
        // at launch) is still waiting in the router.
        if let pending = router.latest {
            handle(pending)
        }
    }

    /// SwiftData cleanup can fetch every saved record. It is important for data quality,
    /// but should not compete with first-launch content such as Home's mini reader.
    private func scheduleInitialDataMaintenance() {
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            _ = await BibleRepository.shared.loadAllBooks()
            guard !Task.isCancelled else { return }
            AppPerformance.measure("InitialDataMaintenance") {
                SwiftDataDeduplicator.run(in: modelContext)
            }
        }
    }

    // MARK: - Routing

    private func handle(_ request: AppRouter.Request) {
        guard request.id != handledRequestID else { return }
        handledRequestID = request.id

        switch request.destination {
        case .tab(let tab):
            selectedTab = tab
        case .favorites:
            showMore(.favorites)
        case .settings:
            showMore(.settings)
        case .stats(let page):
            UserDefaults.standard.set(page.rawValue, forKey: AppStorageKey.statsSelectedMode)
            showMore(.stats)
        case .bibleReference(let location):
            openBibleReference(location)
        case .bibleSearch:
            openBibleSearch()
        case .bibleStudy:
            openBibleStudy()
        case .bibleStudyDestination(let destination):
            openBibleStudy(destination: destination)
        case .verseOfDayNotification:
            handlePendingVerseOfDayNotification()
        case .gameStart:
            // GamesView opens the requested game once it sees this request.
            selectedTab = .games
        case .scripturePreview:
            // Shown by the open note editor.
            break
        }
    }

    private func openBibleStudy(destination: AppRouter.StudyDestination? = nil) {
        selectedTab = .bible
        if usesWideLayout {
            bibleStudyDestination = destination
            bibleStudyRequestID += 1
        } else {
            bibleCoordinator.path = [.study(destination)]
        }
    }

    private func showMore(_ destination: MoreDestination) {
        selectedTab = .more
        DispatchQueue.main.async {
            morePath = [destination]
        }
    }

    private func handleSelectedTabChange(from oldValue: AppTab, to newValue: AppTab) {
        updateGameTimeTracking()
        updateMindfulMinutesTracking()

        // Leaving Games ends any active round and returns its navigation stack to the game list.
        if oldValue == .games && newValue != .games {
            returnToGameSelection()

            // Notify listeners that game stats context changed so Home card can animate if visible
            AppDataChanges.shared.gameStatsChanged()
        }

        if newValue == .home {
            Task { @MainActor in
                await Task.yield()
                ensureSavedFocusLiveActivityIfNeeded()
            }
        }
        // Update previousTab for next transition detection
        previousTab = newValue
    }

    private func handleOpenURL(_ url: URL) {
        // Handle taps from widgets and other custom links.
        switch AppDeepLink(url: url) {
        case .home:
            selectedTab = .home
        case let .open(book, chapter, verse):
            router.openBibleReference(book: book, chapter: chapter, verse: verse)
        case nil:
            break
        }
    }

    private func openBibleReference(_ location: BibleReaderLocation) {
        let bookName = location.bookName
        let chapterNum = location.chapterNumber
        let verseNum = location.verseNumber

        if usesWideLayout {
            // Store the route in ContentView so a newly created split view
            // can consume it after the tab switch. A transient notification
            // could arrive before that view is in the hierarchy.
            launchBibleLocation = BibleReaderLocation(
                bookName: bookName,
                chapterNumber: chapterNum,
                verseNumber: verseNum
            )
            selectedTab = .bible

            // Search focus can cause iPadOS to dismiss the floating tab
            // bar. Recreate only the TabView container after this cross-tab
            // handoff so the system restores its top-level controls.
            DispatchQueue.main.async {
                tabViewRecoveryID &+= 1
            }
        } else {
            // Switch to Bible tab first
            selectedTab = .bible
            // iPhone: push a Route.reader on the Bible NavigationStack
            guard
                let book = bibleStore.books.first(where: { $0.name == bookName }),
                let chapter = book.chapters.first(where: { $0.number == chapterNum })
            else { return }

            // Ensure we’re on the Bible tab before pushing; reset the stack to avoid stacking multiple readers
            DispatchQueue.main.async {
                // Replace the stack in one unanimated step (also prevents duplicate stacked
                // readers). Animating a pop and push while the tab switch is still settling
                // briefly lays the reader out at a transitional width, shifting the card left.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    bibleCoordinator.path = [.reader(book: book, chapter: chapter, startVerse: verseNum)]
                }
                // Safety net: Ensure the reading tracker is running even if the inner view's onAppear is delayed.
                ReadingTimeTracker.shared.start(bookName: book.name, chapter: chapter.number)
                ReadingTimeTracker.shared.setCurrentLocation(bookName: book.name, chapter: chapter.number)
                ReadingTimeTracker.shared.resume()
            }
        }
    }

    private func handleScenePhaseChange(_ newValue: ScenePhase) {
        switch newValue {
        case .active:
            // A Verse of the Day badge represents a notification received while away.
            clearAppIconBadge()
            // Returning to the app counts as activity, so time counts before the first touch.
            UserActivityMonitor.shared.recordInteraction()
            // Pull and merge stats changed on other devices while the app was away.
            iCloudSyncCoordinator.shared.refreshNow()

            SwiftDataDeduplicator.run(in: modelContext)
            updateGameTimeTracking()
            updateMindfulMinutesTracking()
        case .inactive:
            updateGameTimeTracking()
            updateMindfulMinutesTracking()
        case .background:
            updateGameTimeTracking()
            updateMindfulMinutesTracking()
            ReadingPositionStore.shared.flush()
            // An open game stays open: switching apps or taking a call pauses it, and the
            // player comes back to the same round.
        @unknown default:
            break
        }
    }

    // MARK: - Daily usage tracking

    private func returnToGameSelection() {
        guard !gamesPath.isEmpty else { return }
        gamesPath = NavigationPath()
    }

    private func openBibleReaderAtLaunchIfNeeded() {
        guard selectedTab == .bible, !didOpenLaunchBible else { return }
        didOpenLaunchBible = true

        Task {
            let books = await BibleRepository.shared.loadAllBooks()
            guard selectedTab == .bible,
                  let genesis = books.first(where: { $0.name == "Genesis" }) ?? books.first,
                  let genesisOne = genesis.chapters.first(where: { $0.number == 1 }) ?? genesis.chapters.first
            else { return }

            let savedLocation = ReadingPositionStore.shared.current
            let savedBook = savedLocation.flatMap { location in
                books.first(where: { $0.name == location.bookName })
            }
            let savedChapter = savedLocation.flatMap { location in
                savedBook?.chapters.first(where: { $0.number == location.chapterNumber })
            }
            let savedVerse = savedLocation.flatMap { location in
                savedChapter?.verses.first(where: { $0.number == (location.verseNumber ?? 1) })?.number
            }

            let book: Book
            let chapter: Chapter
            let verse: Int
            if let savedBook, let savedChapter, let savedVerse {
                book = savedBook
                chapter = savedChapter
                verse = savedVerse
            } else {
                book = genesis
                chapter = genesisOne
                verse = 1
            }

            let location = BibleReaderLocation(
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse
            )

            if usesWideLayout {
                launchBibleLocation = location
            } else {
                bibleCoordinator.reset()
                bibleCoordinator.push(.reader(book: book, chapter: chapter, startVerse: verse))
                ReadingTimeTracker.shared.start(bookName: book.name, chapter: chapter.number)
                ReadingTimeTracker.shared.setCurrentLocation(bookName: book.name, chapter: chapter.number)
                ReadingTimeTracker.shared.resume()
            }
        }
    }

    private func openBibleSearch() {
        selectedTab = .bible
        if usesWideLayout {
            bibleSearchRequestID &+= 1
        } else {
            DispatchQueue.main.async {
                bibleCoordinator.reset()
                bibleCoordinator.push(.search)
            }
        }
    }

    private func handlePendingVerseOfDayNotification() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: AppStorageKey.pendingVerseOfDayNotification) else { return }
        defaults.set(false, forKey: AppStorageKey.pendingVerseOfDayNotification)

        let verseCardIsVisible = !HomeLayoutStore().load().hidden.contains(.verseOfDay)
        if verseCardIsVisible {
            homeCoordinator.reset()
            selectedTab = .home
            return
        }

        let book = defaults.string(forKey: AppStorageKey.verseOfDayBook) ?? ""
        let chapter = defaults.integer(forKey: AppStorageKey.verseOfDayChapter)
        let verse = defaults.integer(forKey: AppStorageKey.verseOfDayNumber)
        guard !book.isEmpty, chapter > 0, verse > 0 else {
            homeCoordinator.reset()
            selectedTab = .home
            return
        }

        openBibleReference(BibleReaderLocation(bookName: book, chapterNumber: chapter, verseNumber: verse))
    }

    // MARK: - Game time

    private var isPlayingGame: Bool {
        scenePhase == .active && selectedTab == .games && !gamesPath.isEmpty
    }

    private var isOnBibleTab: Bool {
        scenePhase == .active && selectedTab == .bible
    }

    /// Writing study notes and highlights counts as study time.
    private var isOnNotesTab: Bool {
        scenePhase == .active && selectedTab == .notes
    }

    /// Keeps Health mindful-session tracking in sync with foreground Bible and game activity.
    private func updateMindfulMinutesTracking() {
        StudyTimeTracker.shared.setApplicationActive(scenePhase == .active)

        if isOnBibleTab {
            MindfulMinutesTracker.shared.start(.bibleTab)
        } else {
            MindfulMinutesTracker.shared.stop(.bibleTab)
        }

        if isOnNotesTab {
            MindfulMinutesTracker.shared.start(.notesTab)
        } else {
            MindfulMinutesTracker.shared.stop(.notesTab)
        }

        if isPlayingGame {
            MindfulMinutesTracker.shared.start(.game)
        } else {
            MindfulMinutesTracker.shared.stop(.game)
        }
    }

    /// Call after any change to the scene phase, selected tab, or Games navigation.
    private func updateGameTimeTracking() {
        gameTime.update(isPlaying: isPlayingGame)
    }

    // MARK: - Tab reselection

    private func handleTabReselection(_ tab: AppTab) {
        let returnedToRoot: Bool

        switch tab {
        case .home:
            returnedToRoot = !homeCoordinator.path.isEmpty
            homeCoordinator.reset()
        case .bible:
            returnedToRoot = !usesWideLayout && !bibleCoordinator.path.isEmpty
            if !usesWideLayout {
                bibleCoordinator.reset()
            }
        case .notes:
            returnedToRoot = !notesPath.isEmpty
            if returnedToRoot {
                notesPath.removeLast(notesPath.count)
            }
        case .games:
            returnedToRoot = !gamesPath.isEmpty
            if returnedToRoot {
                gamesPath.removeLast(gamesPath.count)
            }
        case .more:
            returnedToRoot = !morePath.isEmpty
            morePath.removeAll()
        }

        guard !returnedToRoot else { return }

        DispatchQueue.main.async {
            TabBarScrollToTop.scrollSelectedTab()
        }
    }

    // MARK: - Helpers

    /// A Verse of the Day badge only indicates that the app has not been opened since it arrived.
    private func clearAppIconBadge() {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    @MainActor
    private func ensureSavedFocusLiveActivityIfNeeded() {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else { return }
        let title = shared.string(forKey: AppStorageKey.focusTitle)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = shared.string(forKey: AppStorageKey.focusBody)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = (!(title?.isEmpty ?? true) || !(body?.isEmpty ?? true))
        if hasContent {
            PrayerTimerActivityController.shared.ensureFocusIfNone(
                title: (title?.isEmpty ?? true) ? nil : title,
                body: (body?.isEmpty ?? true) ? nil : body
            )
        }
    }
}

private struct HomeTabView: View {
    @Binding var path: [Route]
    let coordinator: NavigationCoordinator

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .appDestinations(coordinator: coordinator)
        }
        .environment(coordinator)
    }
}

#Preview {
    ContentView()
}
