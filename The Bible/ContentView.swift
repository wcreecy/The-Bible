//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import SwiftUI
import Combine
import UIKit
import ObjectiveC

struct ContentView: View {
    // Separate coordinators per tab to avoid path leakage/corruption
    @StateObject private var homeCoordinator = NavigationCoordinator()
    @StateObject private var bibleCoordinator = NavigationCoordinator()
    // Favorites, Search, Settings don’t currently push via coordinator; no path binding needed.

    // FIX: Instantiate the ObservableObject
    @StateObject private var journalComposer = JournalComposer()
    @State private var selectedTab: AppTab = .home
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17
    
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = ColorSchemePreference.system.rawValue
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    
    @State private var rootSize: CGSize = .zero
    
    // One-time cleanup flag for deprecated app time keys
    @AppStorage("didCleanupAppTimeKeys") private var didCleanupAppTimeKeys: Bool = false
    // One-time cleanup for deprecated keepScreenOn setting
    @AppStorage("didCleanupKeepScreenOnKey") private var didCleanupKeepScreenOnKey: Bool = false

    // Daily usage tracking (per local day)
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("dailyUsageTodaySeconds") private var dailyUsageTodaySeconds: Int = 0
    @AppStorage("dailyUsageTodayKey") private var dailyUsageTodayKey: String = ""
    @State private var usageTimer: Timer? = nil
    @State private var nextMidnightTimer: Timer? = nil

    // Daily goal minutes (used to determine goal-met)
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    // Timer/Stopwatch state (to account for background time)
    @AppStorage("prayerTimerRunning") private var prayerTimerRunning: Bool = false
    @AppStorage("prayerTimerPaused") private var prayerTimerPaused: Bool = false
    @AppStorage("prayerTimerEndDate") private var prayerTimerEndDate: Double = 0
    @AppStorage("stopwatchRunning") private var stopwatchRunning: Bool = false

    // Track when we went inactive/background to compute elapsed when returning
    @AppStorage("lastBackgroundedAt") private var lastBackgroundedAt: Double = 0

    // Observe reading totals so we can re-check streak when Bible reading time changes
    @State private var readingTotalsCancellable: AnyCancellable? = nil
    
    private var preferredScheme: ColorScheme? { (ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme }
    private var preferredDynamicType: DynamicTypeSize? { (FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize }
    private var preferredFontDesign: Font.Design? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).fontDesign }
    private var preferredCustomFontName: String? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).customFontName }
    
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var isLandscape: Bool { rootSize.width > rootSize.height && rootSize != .zero }
    private var baseFontSize: CGFloat { (isPad && isLandscape) ? 21 : 19 }

    // Track previous tab to detect leaving Games
    @State private var previousTab: AppTab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home tab: its own NavigationStack and coordinator/path
            NavigationStack(path: $homeCoordinator.path) {
                HomeView()
                    .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
            }
            .environmentObject(homeCoordinator)
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)
            
            // Bible tab
            if isPad {
                BibleSplitView()
                    .tabItem { Label("Bible", systemImage: "book") }
                    .tag(AppTab.bible)
            } else {
                NavigationStack(path: $bibleCoordinator.path) {
                    BooksView(books: BibleData.books)
                        .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
                }
                .environmentObject(bibleCoordinator)
                .tabItem { Label("Bible", systemImage: "book") }
                .tag(AppTab.bible)
            }
            
            // Journal tab manages its own navigation
            JournalTabView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(AppTab.journal)
            
            // Games tab: no shared path
            NavigationStack {
                GamesView()
            }
            .tabItem { Label("Games", systemImage: "gamecontroller") }
            .tag(AppTab.games)

            // Stats tab
            NavigationStack {
                StatsView()
            }
            .tabItem { Label("Stats", systemImage: "chart.bar") }
            .tag(AppTab.stats)
            
            // Favorites tab: uses direct NavigationLinks; no shared path
            NavigationStack {
                FavoritesView()
                    .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
            }
            .tabItem { Label("Favorites", systemImage: "heart") }
            .tag(AppTab.favorites)
            
            // Search tab: uses direct NavigationLinks; no shared path
            NavigationStack {
                SearchView()
                    .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)
            
            // Settings tab
            NavigationStack {
                SettingsView()
                    .environment(\.font, nil)
                    .fontDesign(.default)
            }
            .transaction { tx in tx.disablesAnimations = true }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(AppTab.settings)
        }
        .environmentObject(journalComposer)
        // Apply your preferred color scheme even on the Settings tab so it updates in place.
        .preferredColorScheme(preferredScheme)
        .dynamicTypeSize(selectedTab == .settings ? .large : (preferredDynamicType ?? .large))
        .font(
            selectedTab == .settings
            ? .system(size: baseFontSize)
            : (preferredCustomFontName != nil ? .custom(preferredCustomFontName!, size: baseFontSize) : .system(size: baseFontSize))
        )
        .fontDesign(selectedTab == .settings ? .default : (preferredFontDesign ?? .default))
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

            // Prewarm linkify and book names to reduce first-typing latency in Journal
            Task.detached {
                _ = await BibleReferenceLinker.linkify("")
                _ = await BibleLibrary.shared.bookNames()
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

            // Re-check streak when Bible reading totals change
            readingTotalsCancellable = ReadingTimeTracker.shared.$lastTotalsVersion
                .receive(on: RunLoop.main)
                .sink { _ in
                    checkAndMarkGoalIfMet()
                }

            // Initialize previousTab at launch
            previousTab = selectedTab

            // Install background behind the system "More" list on iPhone
            installMoreTabBackground()
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

            if newValue == .home {
                Task { @MainActor in
                    await Task.yield()
                    ensureSavedFocusLiveActivityIfNeeded()
                }
            }
            // Update previousTab for next transition detection
            previousTab = newValue
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { rootSize = proxy.size }
                    .onChange(of: proxy.size) { _, newSize in rootSize = newSize }
            }
        )
        .sheet(isPresented: Binding(
            get: { journalComposer.isPresented },
            set: { newVal in if !newVal { journalComposer.dismiss() } }
        )) {
            JournalEditorView(
                verseRef: journalComposer.verseRef,
                initialBody: journalComposer.initialBody,
                showTagColors: journalComposer.showTagColors,
                editingEntry: journalComposer.editingEntry
            )
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

            if isPad {
                // Re-post once with a "relayed" flag so ContentView ignores it, but BibleSplitView can handle it.
                DispatchQueue.main.async {
                    var user = note.userInfo ?? [:]
                    user["relayed"] = true
                    NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: user)
                }
            } else {
                // iPhone: push a Route.reader on the Bible NavigationStack
                guard
                    let book = BibleData.books.first(where: { $0.name == bookName }),
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
        .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { note in
            // Backward compatibility: accept either Int index or a tab name
            if let tabIndex = note.userInfo?["tab"] as? Int, let t = AppTab(rawValue: tabIndex) {
                selectedTab = t
            } else if let name = note.userInfo?["tabName"] as? String, let t = AppTab.from(name: name) {
                selectedTab = t
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
            selectedTab = .settings
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
                // Also re-check streak status on resume
                checkAndMarkGoalIfMet()

                // Re-ensure the "More" background is installed after app resumes
                installMoreTabBackground()
            case .inactive, .background:
                // Remember when we went foreground to compute elapsed when returning
                lastBackgroundedAt = Date().timeIntervalSince1970
                stopUsageTimer()
            @unknown default:
                break
            }
        }
        // When foreground timer increments, we still call check — now it uses Bible reading totals.
        .onChange(of: dailyUsageTodaySeconds) { _, _ in
            checkAndMarkGoalIfMet()
        }
        // Also re-check when goal minutes changes
        .onChange(of: dailyGoalMinutes) { _, _ in
            checkAndMarkGoalIfMet()
        }
    }

    // MARK: - Daily usage tracking (unchanged)...

    private func todayKey(for date: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0, m = comps.month ?? 0, d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func initializeUsageDayIfNeeded() {
        let key = todayKey()
        if dailyUsageTodayKey != key {
            dailyUsageTodayKey = key
            dailyUsageTodaySeconds = 0
        }
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
            }
            dailyUsageTodaySeconds += 1
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
        // After applying, check if goal is met
        checkAndMarkGoalIfMet()
    }

    private func checkAndMarkGoalIfMet() {
        let goalSeconds = max(1, dailyGoalMinutes) * 60
        // Use Bible reading time (from Bible tab) only
        let todayReadingSeconds = BibleStatsStore.shared.totalForLast(days: 1)
        guard todayReadingSeconds >= goalSeconds else { return }
        // Deprecated marking removed; streaks are computed from totals.
        // Left intentionally blank.
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
            MoreTabStyler.shared.install(on: moreNav, imageName: "river-bg")
        }
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

    private var imageName: String = "river-bg"

    // Adjust this alpha to taste (0 = fully transparent, 1 = opaque)
    private let cellAlpha: CGFloat = 0.90

    func install(on nav: UINavigationController, imageName: String) {
        self.imageName = imageName
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

        // Insert a single background image view behind the nav controller's content
        if nav.view.viewWithTag(987_654) == nil, let img = UIImage(named: imageName) {
            let iv = UIImageView(image: img)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill
            iv.tag = 987_654
            nav.view.insertSubview(iv, at: 0)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: nav.view.topAnchor),
                iv.leadingAnchor.constraint(equalTo: nav.view.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: nav.view.trailingAnchor),
                iv.bottomAnchor.constraint(equalTo: nav.view.bottomAnchor)
            ])
        }

        // Clear backgrounds so the image is visible
        nav.view.backgroundColor = .clear
        nav.topViewController?.view.backgroundColor = .clear

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
        let translucent = UIColor.secondarySystemBackground.withAlphaComponent(cellAlpha)

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
            let translucent = UIColor.secondarySystemBackground.withAlphaComponent(self.cellAlpha)
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
