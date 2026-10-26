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
import ObjectiveC

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
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
    // Reading time comes from ReadingTimeTracker, the single source for reading stats.
    @State private var gameTimeStart: Date?
    @State private var gameTimeFlushTimer: Timer?

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
                NotesAndHighlightsView()
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
        }
    }

    var body: some View {
        tabs
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
            NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
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
        guard url.scheme?.lowercased() == "thebible" else { return }
        let host = url.host?.lowercased() ?? ""

        // thebible://home -> switch to Home tab
        if host == "home" {
            selectedTab = .home
            return
        }

        // Supported deep link: thebible://open?book=Name&chapter=Int&verse=Int
        guard host == "open" else { return }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        var params: [String: String] = [:]
        comps.queryItems?.forEach { params[$0.name.lowercased()] = $0.value ?? "" }
        guard
            let book = params["book"], !book.isEmpty,
            let chapStr = params["chapter"], let chapter = Int(chapStr),
            let verseStr = params["verse"], let verse = Int(verseStr)
        else { return }

        router.openBibleReference(book: book, chapter: chapter, verse: verse)
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
                bibleCoordinator.reset() // <-- prevent duplicate stacked readers after deep links
                bibleCoordinator.push(.reader(book: book, chapter: chapter, startVerse: verseNum))
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
            // Backgrounding ends an active game round so returning to Games shows its selection screen.
            returnToGameSelection()
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

    /// Keeps Health mindful-session tracking in sync with foreground Bible and game activity.
    private func updateMindfulMinutesTracking() {
        StudyTimeTracker.shared.setApplicationActive(scenePhase == .active)

        if isOnBibleTab {
            MindfulMinutesTracker.shared.start(.bibleTab)
        } else {
            MindfulMinutesTracker.shared.stop(.bibleTab)
        }

        if isPlayingGame {
            MindfulMinutesTracker.shared.start(.game)
        } else {
            MindfulMinutesTracker.shared.stop(.game)
        }
    }

    /// Starts or stops counting game time to match whether a game screen is open.
    /// Call after any change to the scene phase, selected tab, or Games navigation.
    private func updateGameTimeTracking() {
        if isPlayingGame {
            guard gameTimeStart == nil else { return }
            gameTimeStart = Date()
            // Persist periodically so a crash or force quit loses at most a few seconds.
            let timer = Timer(timeInterval: 15, repeats: true) { _ in
                MainActor.assumeIsolated { flushGameTime() }
            }
            RunLoop.main.add(timer, forMode: .common)
            gameTimeFlushTimer = timer
        } else {
            flushGameTime()
            gameTimeStart = nil
            gameTimeFlushTimer?.invalidate()
            gameTimeFlushTimer = nil
        }
    }

    private func flushGameTime() {
        guard let start = gameTimeStart else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        guard elapsed > 0 else { return }
        gameTimeStart = start.addingTimeInterval(TimeInterval(elapsed))
        GameStats.shared.recordPlayTime(seconds: elapsed, endingAt: Date())
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
            scrollSelectedTabToTop()
        }
    }

    private func scrollSelectedTabToTop() {
        let tabController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .compactMap(\.rootViewController)
            .compactMap { $0.findTabBarController() }
            .first

        guard
            let rootView = tabController?.selectedViewController?.view,
            let scrollView = rootView.firstScrollableDescendant()
        else { return }

        let topOffset = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(topOffset, animated: true)
    }

    // MARK: - Helpers

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

private struct TabReselectionObserver: UIViewControllerRepresentable {
    let onReselect: (Int) -> Void

    func makeUIViewController(context: Context) -> TabReselectionInstallerViewController {
        TabReselectionInstallerViewController(onReselect: onReselect)
    }

    func updateUIViewController(
        _ uiViewController: TabReselectionInstallerViewController,
        context: Context
    ) {
        uiViewController.onReselect = onReselect
        uiViewController.installIfNeeded()
    }
}

private final class TabReselectionInstallerViewController: UIViewController {
    var onReselect: (Int) -> Void
    private var proxy: TabBarDelegateProxy?

    init(onReselect: @escaping (Int) -> Void) {
        self.onReselect = onReselect
        super.init(nibName: nil, bundle: nil)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installIfNeeded()
    }

    func installIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let tabBarController = self.tabBarController
            else { return }

            if let proxy = self.proxy, tabBarController.delegate === proxy {
                return
            }

            let proxy = TabBarDelegateProxy(
                original: tabBarController.delegate,
                onReselect: { [weak self] index in
                    self?.onReselect(index)
                }
            )
            self.proxy = proxy
            tabBarController.delegate = proxy
        }
    }
}

private final class TabBarDelegateProxy: NSObject, UITabBarControllerDelegate {
    weak var original: UITabBarControllerDelegate?
    let onReselect: (Int) -> Void

    init(
        original: UITabBarControllerDelegate?,
        onReselect: @escaping (Int) -> Void
    ) {
        self.original = original
        self.onReselect = onReselect
        super.init()
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        let shouldSelect = original?.tabBarController?(
            tabBarController,
            shouldSelect: viewController
        ) ?? true

        if shouldSelect,
           viewController === tabBarController.selectedViewController,
           let index = tabBarController.viewControllers?.firstIndex(of: viewController) {
            DispatchQueue.main.async { [onReselect] in
                onReselect(index)
            }
        }

        return shouldSelect
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) {
            return original
        }
        return super.forwardingTarget(for: aSelector)
    }
}

private extension UIView {
    func firstScrollableDescendant() -> UIScrollView? {
        if let scrollView = self as? UIScrollView,
           scrollView.isScrollEnabled,
           !scrollView.isHidden,
           scrollView.alpha > 0 {
            return scrollView
        }

        for subview in subviews {
            if let scrollView = subview.firstScrollableDescendant() {
                return scrollView
            }
        }

        return nil
    }
}

private extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        if let t = self as? UITabBarController { return t }
        if let nav = self as? UINavigationController {
            for vc in nav.viewControllers {
                if let t = vc.findTabBarController() { return t }
            }
        }
        for child in children {
            if let t = child.findTabBarController() { return t }
        }
        if let presented = presentedViewController {
            return presented.findTabBarController()
        }
        return nil
    }
}

#Preview {
    ContentView()
}
