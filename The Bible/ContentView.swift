//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import SwiftUI
import Combine

extension Notification.Name {
    static let openBibleReference = Notification.Name("OpenBibleReference")
    static let openSettingsTab = Notification.Name("OpenSettingsTab")
    // Use the centralized definition of `switchToTab` in iCloudSyncCoordinator.swift
    static let resetBibleNavigation = Notification.Name("ResetBibleNavigation")
}

struct ContentView: View {
    // Separate coordinators per tab to avoid path leakage/corruption
    @StateObject private var homeCoordinator = NavigationCoordinator()
    @StateObject private var bibleCoordinator = NavigationCoordinator()
    // Favorites, Search, Settings don’t currently push via coordinator; no path binding needed.

    // FIX: Instantiate the ObservableObject
    @StateObject private var journalComposer = JournalComposer()
    @State private var selectedTab: Int = 0
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
    @State private var previousTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home tab: its own NavigationStack and coordinator/path
            NavigationStack(path: $homeCoordinator.path) {
                HomeView()
                    .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
            }
            .environmentObject(homeCoordinator)
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)
            
            // Bible tab
            if isPad {
                BibleSplitView()
                    .tabItem { Label("Bible", systemImage: "book") }
                    .tag(1)
            } else {
                NavigationStack(path: $bibleCoordinator.path) {
                    BooksView(books: BibleData.books)
                        .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
                }
                .environmentObject(bibleCoordinator)
                .tabItem { Label("Bible", systemImage: "book") }
                .tag(1)
            }
            
            // Journal tab manages its own navigation
            JournalTabView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(2)
            
            // Games tab: no shared path
            NavigationStack {
                GamesView()
            }
            .tabItem { Label("Games", systemImage: "gamecontroller") }
            .tag(3)
            
            // Favorites tab: uses direct NavigationLinks; no shared path
            NavigationStack {
                FavoritesView()
                    .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
            }
            .tabItem { Label("Favorites", systemImage: "heart") }
            .tag(4)
            
            // Search tab: uses direct NavigationLinks; no shared path
            NavigationStack {
                SearchView()
                    .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(5)

            // NEW: Stats tab (placeholder)
            NavigationStack {
                StatsView()
            }
            .tabItem { Label("Stats", systemImage: "chart.bar") }
            .tag(6)
            
            // Settings tab
            NavigationStack {
                SettingsView()
                    .environment(\.font, nil)
                    .fontDesign(.default)
            }
            .transaction { tx in tx.disablesAnimations = true }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(7)
        }
        .environmentObject(journalComposer)
        .preferredColorScheme(selectedTab == 7 ? nil : preferredScheme)
        .dynamicTypeSize(selectedTab == 7 ? .large : (preferredDynamicType ?? .large))
        .font(
            selectedTab == 7
            ? .system(size: baseFontSize)
            : (preferredCustomFontName != nil ? .custom(preferredCustomFontName!, size: baseFontSize) : .system(size: baseFontSize))
        )
        .fontDesign(selectedTab == 7 ? .default : (preferredFontDesign ?? .default))
        .onAppear {
            // Start iCloud Key-Value sync coordinator globally (ensures cross-device merges are observed)
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
                if selectedTab == 0 {
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
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // When leaving Games tab (3), persist latest session accuracy baseline for the Home games card caret
            if previousTab == 3 && newValue != 3 {
                let today = GameStats.shared.todayStats()
                // Reuse the existing baseline key the GamesCard reads
                UserDefaults.standard.set(today.pct, forKey: "gamesLastWeekAccuracyPct")
                // Notify listeners that game stats context changed so Home card can animate if visible
                NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
            }

            // NEW: When entering Games tab, capture session baseline of all‑time Gamer Score
            if newValue == 3 {
                let baselinePct = GameStats.shared.breakdownSnapshot().percentage
                UserDefaults.standard.set(baselinePct, forKey: "gamesSessionBaselinePct")
            }

            if newValue == 0 {
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
                selectedTab = 0
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
            selectedTab = 1

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
            if let tab = note.userInfo?["tab"] as? Int {
                selectedTab = tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
            selectedTab = 7
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetBibleNavigation)) { _ in
            // Ensure Bible tab is visible, then reset the Bible nav stack to Books list
            selectedTab = 1
            DispatchQueue.main.async {
                bibleCoordinator.reset()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Account for any background elapsed time while timer/stopwatch was running
                applyBackgroundElapsedIfAny()
                // Start foreground usage timer
                startUsageTimerIfNeeded()
                // Also re-check streak status on resume
                checkAndMarkGoalIfMet()
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
}

#Preview {
    ContentView()
}
