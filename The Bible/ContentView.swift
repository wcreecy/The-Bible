//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import SwiftUI

struct ContentView: View {
    // Separate coordinators per tab to avoid path leakage/corruption
    @StateObject private var homeCoordinator = NavigationCoordinator()
    @StateObject private var bibleCoordinator = NavigationCoordinator()
    // Favorites, Search, Settings don’t currently push via coordinator; no path binding needed.

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
    
    private var preferredScheme: ColorScheme? { (ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme }
    private var preferredDynamicType: DynamicTypeSize? { (FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize }
    private var preferredFontDesign: Font.Design? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).fontDesign }
    private var preferredCustomFontName: String? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).customFontName }
    
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var isLandscape: Bool { rootSize.width > rootSize.height && rootSize != .zero }
    private var baseFontSize: CGFloat { (isPad && isLandscape) ? 21 : 19 }
    
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
            
            // Settings tab
            NavigationStack {
                SettingsView()
                    .appDestinations(readerFontSize: $readerFontSize, isPad: isPad)
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(6)
        }
        // Only share the journal composer globally
        .environmentObject(journalComposer)
        .preferredColorScheme(preferredScheme)
        .dynamicTypeSize(preferredDynamicType ?? .large)
        .font(preferredCustomFontName != nil ? .custom(preferredCustomFontName!, size: baseFontSize) : .system(size: baseFontSize))
        .fontDesign(preferredFontDesign ?? .default)
        .onAppear {
            // One-time cleanup of deprecated app time keys (cheap)
            if !didCleanupAppTimeKeys {
                UserDefaults.standard.removeObject(forKey: "appTotalActiveSeconds")
                UserDefaults.standard.removeObject(forKey: "appActiveStart")
                didCleanupAppTimeKeys = true
            }
            // One-time cleanup of deprecated keepScreenOn setting
            if !didCleanupKeepScreenOnKey {
                UserDefaults.standard.removeObject(forKey: "keepScreenOn")
                didCleanupKeepScreenOnKey = true
            }
            // Defer Live Activity "ensure" to the next runloop/frame, and only if Home is visible now.
            Task { @MainActor in
                await Task.yield()
                if selectedTab == 0 {
                    ensureSavedFocusLiveActivityIfNeeded()
                }
            }
        }
        // If the user switches to Home later, ensure Focus activity then (still lightweight).
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 0 {
                Task { @MainActor in
                    await Task.yield()
                    ensureSavedFocusLiveActivityIfNeeded()
                }
            }
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
            JournalEditorView(verseRef: journalComposer.verseRef, initialBody: journalComposer.initialBody, showTagColors: journalComposer.showTagColors, editingEntry: journalComposer.editingEntry)
        }
        .onOpenURL { url in
            guard url.scheme == "thebible" else { return }
            switch url.host?.lowercased() {
            case "timer":
                selectedTab = 0
                UserDefaults.standard.set("timer", forKey: "prayerMode")
                if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let action = comps.queryItems?.first(where: { $0.name == "action" })?.value,
                   let shared = UserDefaults(suiteName: "group.bible.app") {
                    shared.set(action, forKey: "prayerTimerPendingAction")
                }
            case "stopwatch":
                selectedTab = 0
                UserDefaults.standard.set("stopwatch", forKey: "prayerMode")
                if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let action = comps.queryItems?.first(where: { $0.name == "action" })?.value,
                   let shared = UserDefaults(suiteName: "group.bible.app") {
                    let mapped: String
                    switch action.lowercased() {
                    case "pause": mapped = "togglePause"
                    case "stop": mapped = "stop"
                    default: mapped = action
                    }
                    shared.set(mapped, forKey: "stopwatchPendingAction")
                }
            case "focus":
                selectedTab = 0
                UserDefaults.standard.set("focus", forKey: "prayerMode")
            case "open":
                // Deep link from Last Read widget: thebible://open?book=...&chapter=...&verse=...
                guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
                let q = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name.lowercased(), $0.value ?? "") })
                let bookName = q["book"] ?? ""
                let chapterNum = Int(q["chapter"] ?? "") ?? 0
                let verseNum = Int(q["verse"] ?? "") ?? 0
                guard !bookName.isEmpty, chapterNum > 0, verseNum > 0 else { return }

                // Resolve to model objects
                let maybeBook = BibleData.books.first { $0.name == bookName }
                let maybeChapter = maybeBook?.chapters.first { $0.number == chapterNum }

                if !isPad, let book = maybeBook, let chapter = maybeChapter {
                    // iPhone: push directly on the Bible tab’s coordinator
                    selectedTab = 1
                    // Defer push to next runloop so the tab switch completes first
                    DispatchQueue.main.async {
                        bibleCoordinator.push(.reader(book: book, chapter: chapter, startVerse: verseNum))
                    }
                } else {
                    // iPad or fallback: use Home’s pending mechanism (already implemented in HomeView)
                    if let shared = UserDefaults(suiteName: "group.bible.app") {
                        shared.set(bookName, forKey: "pendingOpenBook")
                        shared.set(chapterNum, forKey: "pendingOpenChapter")
                        shared.set(verseNum, forKey: "pendingOpenVerse")
                    }
                    selectedTab = 0
                }
            default:
                break
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func ensureSavedFocusLiveActivityIfNeeded() {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else { return }
        let title = shared.string(forKey: "focusTitle")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = shared.string(forKey: "focusBody")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = ((title?.isEmpty == false) || (body?.isEmpty == false))
        if hasContent {
            PrayerTimerActivityController.shared.ensureFocusIfNone(
                title: title?.isEmpty == true ? nil : title,
                body: body?.isEmpty == true ? nil : body
            )
        }
    }
}

#Preview {
    ContentView()
}
