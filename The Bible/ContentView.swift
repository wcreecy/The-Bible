//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import Combine
import HealthKit
import SwiftUI
import UIKit
import ObjectiveC

struct ContentView: View {
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Separate coordinators per tab to avoid path leakage/corruption
    @StateObject private var homeCoordinator = NavigationCoordinator()
    @StateObject private var bibleCoordinator = NavigationCoordinator()
    @StateObject private var bibleStore = BibleStore.shared
    @State private var notesPath = NavigationPath()
    @State private var gamesPath = NavigationPath()
    @State private var morePath: [MoreDestination] = []

    @State private var selectedTab: AppTab = .home
    @State private var bibleSearchRequestID: Int = 0
    @AppStorage("healthKitPrompted") private var healthKitPrompted: Bool = false
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17
    
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = ColorSchemePreference.system.rawValue
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    
    // One-time cleanup flag for deprecated app time keys
    @AppStorage("didCleanupAppTimeKeys") private var didCleanupAppTimeKeys: Bool = false
    // One-time cleanup for deprecated keepScreenOn setting
    @AppStorage("didCleanupKeepScreenOnKey") private var didCleanupKeepScreenOnKey: Bool = false

    // Daily usage tracking (per local day)
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("dailyUsageTodaySeconds") private var dailyUsageTodaySeconds: Int = 0
    @AppStorage("dailyUsageReadingSeconds") private var dailyUsageReadingSeconds: Int = 0
    @AppStorage("dailyUsageGameSeconds") private var dailyUsageGameSeconds: Int = 0
    @AppStorage("allTimeUsageReadingSeconds") private var allTimeUsageReadingSeconds: Int = 0
    @AppStorage("allTimeUsageGameSeconds") private var allTimeUsageGameSeconds: Int = 0
    @AppStorage("dailyUsageTodayKey") private var dailyUsageTodayKey: String = ""
    @State private var usageTimer: Timer? = nil
    @State private var nextMidnightTimer: Timer? = nil

    // Timer/Stopwatch state (to account for background time)
    @AppStorage("prayerTimerRunning") private var prayerTimerRunning: Bool = false
    @AppStorage("prayerTimerPaused") private var prayerTimerPaused: Bool = false
    @AppStorage("prayerTimerEndDate") private var prayerTimerEndDate: Double = 0
    @AppStorage("stopwatchRunning") private var stopwatchRunning: Bool = false

    // Track when we went inactive/background to compute elapsed when returning
    @AppStorage("lastBackgroundedAt") private var lastBackgroundedAt: Double = 0

    private var preferredScheme: ColorScheme? { (ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme }
    private var preferredDynamicType: DynamicTypeSize? { (FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize }
    private var preferredFontDesign: Font.Design? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).fontDesign }
    private var preferredCustomFontName: String? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).customFontName }
    
    private var usesWideLayout: Bool { horizontalSizeClass == .regular }
    private var preferredFont: Font? {
        guard let name = preferredCustomFontName else { return nil }
        return .custom(name, size: 17, relativeTo: .body)
    }

    // Track previous tab to detect leaving Games
    @State private var previousTab: AppTab = .home
    
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homeCoordinator.path) {
                HomeView()
                    .appDestinations(readerFontSize: $readerFontSize, isPad: usesWideLayout)
            }
            .environmentObject(homeCoordinator)
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            if usesWideLayout {
                BibleSplitView(searchRequestID: bibleSearchRequestID)
                    .tabItem { Label("Bible", systemImage: "book") }
                    .tag(AppTab.bible)
            } else {
                NavigationStack(path: $bibleCoordinator.path) {
                    BooksView(books: bibleStore.books)
                        .appDestinations(readerFontSize: $readerFontSize, isPad: usesWideLayout)
                }
                .environmentObject(bibleCoordinator)
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
        .dynamicTypeSize(preferredDynamicType ?? systemDynamicTypeSize)
        .font(preferredFont)
        .fontDesign(preferredFontDesign ?? .default)
        .onAppear {
            // START iCloud KVS coordinator so game/bible stats pull/merge on launch.
            iCloudSyncCoordinator.shared.start()

            // One-time cleanup of deprecated keys
            if !didCleanupAppTimeKeys {
                UserDefaults.standard.removeObject(forKey: "appTotalActiveSeconds")
                UserDefaults.standard.removeObject(forKey: "appActiveStart")
                didCleanupAppTimeKeys = true
            }
            if !didCleanupKeepScreenOnKey {
                UserDefaults.standard.removeObject(forKey: "keepScreenOn")
                didCleanupKeepScreenOnKey = true
            }

            bibleStore.ensureLoaded()

            Task.detached {
                _ = await BibleReferenceLinker.linkify("")
            }

            Task { @MainActor in
                await Task.yield()
                if selectedTab == .home {
                    ensureSavedFocusLiveActivityIfNeeded()
                }
            }

            // Initialize daily usage tracking day key and rollover timer
            initializeUsageDayIfNeeded()
            scheduleMidnightRollover()

            // Initialize previousTab at launch
            previousTab = selectedTab
            handlePendingVerseOfDayNotification()

        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // When leaving Games tab, persist latest session accuracy baseline for the Home games card caret
            if previousTab == .games && newValue != .games {
                let today = GameStats.shared.todayStats()
                // Reuse the existing baseline key the GamesCard reads
                UserDefaults.standard.set(today.pct, forKey: "gamesLastWeekAccuracyPct")
                // Notify listeners that game stats context changed so Home card can animate if visible
                NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
            }

            // When entering Games tab, capture session baseline of all‑time Gamer Score
            if newValue == .games {
                let baselinePct = GameStats.shared.breakdownSnapshot().percentage
                UserDefaults.standard.set(baselinePct, forKey: "gamesSessionBaselinePct")
            }

            if newValue == .bible {
                requestMindfulMinutesAuthorizationIfNeeded()
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
        .onOpenURL { url in
            // Handle taps from widgets and other custom links.
            guard url.scheme?.lowercased() == "thebible" else { return }
            let host = url.host?.lowercased() ?? ""

            // NEW: thebible://home -> switch to Home tab
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

            // Forward to existing in-app router via notification
            NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: [
                "book": book,
                "chapter": chapter,
                "verse": verse
            ])
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBibleReference)) { note in
            // Avoid handling the relayed copy we post for iPad; let BibleSplitView consume that
            if let relayed = note.userInfo?["relayed"] as? Bool, relayed {
                return
            }

            guard
                let bookName = note.userInfo?["book"] as? String,
                let chapterNum = note.userInfo?["chapter"] as? Int,
                let verseNum = note.userInfo?["verse"] as? Int
            else { return }

            // Switch to Bible tab first
            selectedTab = .bible

            if usesWideLayout {
                // Re-post once with a "relayed" flag so ContentView ignores it, but BibleSplitView can handle it.
                DispatchQueue.main.async {
                    var user = note.userInfo ?? [:]
                    user["relayed"] = true
                    NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: user)
                }
            } else {
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
        .onReceive(
            NotificationCenter.default.publisher(for: .switchToTab)
                .merge(with: NotificationCenter.default.publisher(for: .openVerseOfDayNotification))
        ) { note in
            handleTabNotification(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
            selectedTab = .more
            DispatchQueue.main.async {
                morePath = [.settings]
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openStats)) { _ in
            selectedTab = .more
            DispatchQueue.main.async {
                morePath = [.stats]
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBibleSearch)) { note in
            handleOpenBibleSearch(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetBibleNavigation)) { _ in
            // Ensure Bible tab is visible, then reset the Bible nav stack to Books list
            selectedTab = .bible
            DispatchQueue.main.async {
                bibleCoordinator.reset()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            switch newValue {
            case .active:
                // Re-run start (idempotent) to ensure any missed merges are reconciled on resume.
                iCloudSyncCoordinator.shared.start()

                // Account for any background elapsed time while timer/stopwatch was running
                applyBackgroundElapsedIfAny()
                // Start foreground usage timer
                startUsageTimerIfNeeded()
            case .inactive, .background:
                // Remember when we went foreground to compute elapsed when returning
                lastBackgroundedAt = Date().timeIntervalSince1970
                stopUsageTimer()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Daily usage tracking (unchanged)...

    private func handleTabNotification(_ notification: Notification) {
        if notification.name == .openVerseOfDayNotification {
            handlePendingVerseOfDayNotification()
            return
        }

        if let tabIndex = notification.userInfo?["tab"] as? Int,
           let tab = AppTab(rawValue: tabIndex) {
            selectedTab = tab
            return
        }

        guard let name = notification.userInfo?["tabName"] as? String,
              let tab = AppTab.from(name: name) else { return }

        selectedTab = tab
        if name.lowercased() == "favorites" {
            DispatchQueue.main.async {
                morePath = [.favorites]
            }
        }
    }

    private func handleOpenBibleSearch(_ notification: Notification) {
        if let relayed = notification.userInfo?["relayed"] as? Bool, relayed {
            return
        }

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

    private func requestMindfulMinutesAuthorizationIfNeeded() {
        guard HealthKitManager.shared.isAvailable(),
              HealthKitManager.shared.mindfulMinutesAuthorizationStatus() == .notDetermined,
              !healthKitPrompted else { return }

        HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
            healthKitPrompted = true
        }
    }

    private func todayKey(for date: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0, m = comps.month ?? 0, d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func handlePendingVerseOfDayNotification() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "pendingVerseOfDayNotification") else { return }
        defaults.set(false, forKey: "pendingVerseOfDayNotification")

        let verseCardIsVisible = !HomeLayoutStore().load().hidden.contains(.verseOfDay)
        if verseCardIsVisible {
            homeCoordinator.reset()
            selectedTab = .home
            return
        }

        let book = defaults.string(forKey: "verseOfDayBook") ?? ""
        let chapter = defaults.integer(forKey: "verseOfDayChapter")
        let verse = defaults.integer(forKey: "verseOfDayNumber")
        guard !book.isEmpty, chapter > 0, verse > 0 else {
            homeCoordinator.reset()
            selectedTab = .home
            return
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .openBibleReference,
                object: nil,
                userInfo: ["book": book, "chapter": chapter, "verse": verse]
            )
        }
    }

    private func initializeUsageDayIfNeeded() {
        let key = todayKey()
        if dailyUsageTodayKey != key {
            dailyUsageTodayKey = key
            dailyUsageTodaySeconds = 0
            dailyUsageReadingSeconds = 0
            dailyUsageGameSeconds = 0
        }

        // Existing installs may already have today's usage but no cumulative counters.
        allTimeUsageReadingSeconds = max(allTimeUsageReadingSeconds, dailyUsageReadingSeconds)
        allTimeUsageGameSeconds = max(allTimeUsageGameSeconds, dailyUsageGameSeconds)
    }

    private func scheduleMidnightRollover() {
        nextMidnightTimer?.invalidate()
        let cal = Calendar.current
        let now = Date()
        guard let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) else { return }
        let interval = startOfTomorrow.timeIntervalSince(now)
        nextMidnightTimer = Timer.scheduledTimer(withTimeInterval: max(1, interval), repeats: false) { _ in
            // Rollover day
            dailyUsageTodayKey = todayKey()
            dailyUsageTodaySeconds = 0
            dailyUsageReadingSeconds = 0
            dailyUsageGameSeconds = 0
            // Reschedule for next midnight
            scheduleMidnightRollover()
        }
        if let t = nextMidnightTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func startUsageTimerIfNeeded() {
        initializeUsageDayIfNeeded()
        guard usageTimer == nil else { return }
        usageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let key = todayKey()
            if key != dailyUsageTodayKey {
                dailyUsageTodayKey = key
                dailyUsageTodaySeconds = 0
                dailyUsageReadingSeconds = 0
                dailyUsageGameSeconds = 0
            }

            dailyUsageTodaySeconds += 1

            switch selectedTab {
            case .games:
                dailyUsageGameSeconds += 1
                allTimeUsageGameSeconds = max(
                    allTimeUsageGameSeconds + 1,
                    dailyUsageGameSeconds
                )
            case .bible, .notes:
                dailyUsageReadingSeconds += 1
                allTimeUsageReadingSeconds = max(
                    allTimeUsageReadingSeconds + 1,
                    dailyUsageReadingSeconds
                )
            case .more:
                if case .favorites? = morePath.last {
                    dailyUsageReadingSeconds += 1
                    allTimeUsageReadingSeconds = max(
                        allTimeUsageReadingSeconds + 1,
                        dailyUsageReadingSeconds
                    )
                }
            case .home:
                break
            }
        }
        if let t = usageTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func stopUsageTimer() {
        usageTimer?.invalidate()
        usageTimer = nil
    }

    private func applyBackgroundElapsedIfAny() {
        guard lastBackgroundedAt > 0 else { return }
        let now = Date().timeIntervalSince1970
        let backgroundDelta = max(0, now - lastBackgroundedAt)

        var addSeconds = 0

        // If Prayer Timer was running and not paused, count up to its end date
        if prayerTimerRunning && !prayerTimerPaused && prayerTimerEndDate > 0 {
            let cappedEnd = max(0, prayerTimerEndDate - lastBackgroundedAt)
            let timerDelta = Int(min(backgroundDelta, cappedEnd))
            addSeconds += max(0, timerDelta)
        }

        // If Stopwatch was running, count full delta
        if stopwatchRunning {
            addSeconds += Int(backgroundDelta)
        }

        if addSeconds > 0 {
            // Ensure we're on today's bucket
            initializeUsageDayIfNeeded()
            dailyUsageTodaySeconds += addSeconds
        }

        lastBackgroundedAt = 0
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
        let title = shared.string(forKey: "focusTitle")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = shared.string(forKey: "focusBody")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = (!(title?.isEmpty ?? true) || !(body?.isEmpty ?? true))
        if hasContent {
            PrayerTimerActivityController.shared.ensureFocusIfNone(
                title: (title?.isEmpty ?? true) ? nil : title,
                body: (body?.isEmpty ?? true) ? nil : body
            )
        }
    }

    // MARK: - "More" tab background for iPhone

    private func installMoreTabBackground() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        DispatchQueue.main.async {
            // Find the UITabBarController SwiftUI creates
            let tab: UITabBarController? = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .compactMap { $0.rootViewController }
                .compactMap { $0.findTabBarController() }
                .first

            guard let tab else { return }

            // Hook and style the system "More" navigation controller
            let moreNav = tab.moreNavigationController
            MoreTabStyler.shared.install(on: moreNav)
        }
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

// Helper that keeps the background in place even when "More" pushes/pops).
private final class MoreTabStyler: NSObject, UINavigationControllerDelegate {
    static let shared = MoreTabStyler()

    // Adjust this alpha to taste (0 = fully transparent, 1 = opaque)
    private let cellAlpha: CGFloat = 0.90

    func install(on nav: UINavigationController) {
        nav.delegate = self
        // Kick off a series of styling passes so the very first visit is covered
        schedulePostShowStyling(on: nav)
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        schedulePostShowStyling(on: navigationController)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        schedulePostShowStyling(on: navigationController)
    }

    // Run several passes over the next few runloops to catch the table after layout
    private func schedulePostShowStyling(on nav: UINavigationController) {
        let delays: [TimeInterval] = [0.0, 0.03, 0.10, 0.25]
        for d in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + d) { [weak self, weak nav] in
                guard let self, let nav else { return }
                self.apply(to: nav)
            }
        }
    }

    private func apply(to nav: UINavigationController) {
        // Ensure hierarchy is loaded
        _ = nav.topViewController?.view

        nav.view.backgroundColor = .systemGroupedBackground
        nav.topViewController?.view.backgroundColor = .systemGroupedBackground

        // Style the More list table and its cells
        if let table = findTable(in: nav.view) {
            styleMoreTable(table)
            ensureDelegateProxy(for: table)
        }
    }

    private func findTable(in root: UIView) -> UITableView? {
        if let t = root as? UITableView { return t }
        for sub in root.subviews {
            if let t = findTable(in: sub) { return t }
        }
        return nil
    }

    private func styleMoreTable(_ table: UITableView) {
        table.isOpaque = false
        table.backgroundColor = .clear
        table.backgroundView = nil
        table.separatorColor = UIColor.separator.withAlphaComponent(0.5)
        table.tableHeaderView?.backgroundColor = .clear
        table.tableFooterView?.backgroundColor = .clear

        // Pass 1: style any already-visible cells
        styleVisibleCells(in: table)
    }

    private func styleVisibleCells(in table: UITableView) {
        let translucent = UIColor.clear.withAlphaComponent(cellAlpha)

        // Ensure the table has laid out its cells before styling
        table.layoutIfNeeded()

        for cell in table.visibleCells {
            applyTranslucency(to: cell, color: translucent, trait: table.traitCollection)
        }
    }

    private func applyTranslucency(to cell: UITableViewCell, color: UIColor, trait: UITraitCollection) {
        cell.isOpaque = false
        cell.layer.isOpaque = false

        // Single translucent layer across the whole row via backgroundView
        cell.contentView.isOpaque = false
        cell.contentView.layer.isOpaque = false
        cell.contentView.backgroundColor = .clear
        cell.backgroundColor = .clear

        // Provide one background layer that fills the entire cell (content + accessory areas)
        let bg = cell.backgroundView ?? UIView()
        bg.isOpaque = false
        bg.layer.isOpaque = false
        bg.backgroundColor = color
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bg.frame = cell.bounds
        cell.backgroundView = bg

        // Disable automatic list background painting to avoid subtle alpha differences
        if #available(iOS 15.0, *) {
            cell.automaticallyUpdatesBackgroundConfiguration = false
        }
        if #available(iOS 14.0, *) {
            cell.backgroundConfiguration = nil
        }

        // Selected background uses the exact same translucency (no added alpha)
        if cell.selectedBackgroundView == nil {
            let sel = UIView()
            sel.isOpaque = false
            sel.layer.isOpaque = false
            sel.backgroundColor = color
            sel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            cell.selectedBackgroundView = sel
        } else {
            cell.selectedBackgroundView?.isOpaque = false
            cell.selectedBackgroundView?.layer.isOpaque = false
            cell.selectedBackgroundView?.backgroundColor = color
        }

        // Adaptive chevron color: black in light mode, white in dark mode
        let isDark = (trait.userInterfaceStyle == .dark)
        let chevronBase: UIColor = isDark ? .white : .black
        let chevronColor = chevronBase.withAlphaComponent(0.95)

        // Chevron tint; leave its background clear so we keep exactly one translucent layer
        cell.tintColor = chevronColor
        if let iv = cell.accessoryView as? UIImageView {
            iv.tintColor = chevronColor
            iv.alpha = 0.95
            iv.isOpaque = false
            iv.layer.isOpaque = false
            iv.backgroundColor = .clear
        } else if cell.accessoryType == .disclosureIndicator {
            // Replace system indicator with a tinted SF Symbol for reliable alpha/color control
            let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let img = UIImage(systemName: "chevron.right", withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
            let iv = UIImageView(image: img)
            iv.tintColor = chevronColor
            iv.alpha = 0.95
            iv.contentMode = .center
            iv.isOpaque = false
            iv.layer.isOpaque = false
            iv.backgroundColor = .clear
            iv.frame = CGRect(x: 0, y: 0, width: 12, height: 20)
            cell.accessoryView = iv
            cell.accessoryType = .none
        }

        // Labels shouldn’t add their own opaque backgrounds
        cell.textLabel?.backgroundColor = .clear
        cell.detailTextLabel?.backgroundColor = .clear
    }

    // MARK: - Delegate proxy to restyle every cell when it appears

    private func ensureDelegateProxy(for table: UITableView) {
        let key = UnsafeRawPointer(bitPattern: 0xB17E_BABE)!
        if objc_getAssociatedObject(table, key) != nil {
            return
        }
        let original = table.delegate
        let proxy = TableDelegateProxy(original: original) { [weak self, weak table] cell in
            guard let self, let table else { return }
            let translucent = UIColor.clear.withAlphaComponent(self.cellAlpha)
            self.applyTranslucency(to: cell, color: translucent, trait: table.traitCollection)
        }
        table.delegate = proxy
        objc_setAssociatedObject(table, key, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private final class TableDelegateProxy: NSObject, UITableViewDelegate {
    weak var original: UITableViewDelegate?
    private let styler: (UITableViewCell) -> Void

    init(original: UITableViewDelegate?, styler: @escaping (UITableViewCell) -> Void) {
        self.original = original
        self.styler = styler
        super.init()
    }

    // Intercept willDisplay to restyle each cell
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        styler(cell)
        original?.tableView?(tableView, willDisplay: cell, forRowAt: indexPath)
    }

    // Forward everything else to the original delegate
    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return original?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) {
            return original
        }
        return super.forwardingTarget(for: aSelector)
    }
}

#Preview {
    ContentView()
}
