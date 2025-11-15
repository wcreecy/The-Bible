//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = NavigationCoordinator()
    @StateObject private var journalComposer = JournalComposer()
    @State private var selectedTab: Int = 0
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17
    
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = ColorSchemePreference.system.rawValue
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    
    @State private var rootSize: CGSize = .zero
    
    // One-time cleanup flag for deprecated app time keys
    @AppStorage("didCleanupAppTimeKeys") private var didCleanupAppTimeKeys: Bool = false
    
    private var preferredScheme: ColorScheme? { (ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme }
    private var preferredDynamicType: DynamicTypeSize? { (FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize }
    private var preferredFontDesign: Font.Design? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).fontDesign }
    private var preferredCustomFontName: String? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).customFontName }
    
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var isLandscape: Bool { rootSize.width > rootSize.height && rootSize != .zero }
    private var baseFontSize: CGFloat { (isPad && isLandscape) ? 21 : 19 }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $coordinator.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case let .book(book):
                            ChaptersView(book: book)
                                .navigationBarTitleDisplayMode(.inline)
                        case let .chapter(book, chapter):
                            VersesView(book: book, chapter: chapter)
                                .navigationBarTitleDisplayMode(.inline)
                        case let .reader(book, chapter, startVerse):
                            ReadingView(book: book, chapter: chapter, startVerse: startVerse)
                                .navigationBarTitleDisplayMode(.inline)
                                .font(.system(size: readerFontSize))
                                .toolbar {
                                    if isPad {
                                        ToolbarItemGroup(placement: .topBarTrailing) {
                                            Button {
                                                readerFontSize = max(12, readerFontSize - 1)
                                            } label: {
                                                Image(systemName: "textformat.size.smaller")
                                            }
                                            .accessibilityLabel("Decrease font size")

                                            Button {
                                                readerFontSize = min(30, readerFontSize + 1)
                                            } label: {
                                                Image(systemName: "textformat.size.larger")
                                            }
                                            .accessibilityLabel("Increase font size")
                                        }
                                    }
                                }
                        }
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)
            
            if isPad {
                BibleSplitView()
                    .tabItem { Label("Bible", systemImage: "book") }
                    .tag(1)
            } else {
                NavigationStack(path: $coordinator.path) {
                    BooksView(books: BibleData.books)
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case let .book(book):
                                ChaptersView(book: book)
                                    .navigationBarTitleDisplayMode(.inline)
                            case let .chapter(book, chapter):
                                VersesView(book: book, chapter: chapter)
                                    .navigationBarTitleDisplayMode(.inline)
                            case let .reader(book, chapter, startVerse):
                                ReadingView(book: book, chapter: chapter, startVerse: startVerse)
                                    .navigationBarTitleDisplayMode(.inline)
                                    .font(.system(size: readerFontSize))
                                    .toolbar {
                                        if isPad {
                                            ToolbarItemGroup(placement: .topBarTrailing) {
                                                Button {
                                                    readerFontSize = max(12, readerFontSize - 1)
                                                } label: {
                                                    Image(systemName: "textformat.size.smaller")
                                                }
                                                .accessibilityLabel("Decrease font size")

                                                Button {
                                                    readerFontSize = min(30, readerFontSize + 1)
                                                } label: {
                                                    Image(systemName: "textformat.size.larger")
                                                }
                                                .accessibilityLabel("Increase font size")
                                            }
                                        }
                                    }
                            }
                        }
                }
                .tabItem { Label("Bible", systemImage: "book") }
                .tag(1)
            }
            
            JournalTabView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(2)
            
            NavigationStack {
                GamesView()
            }
            .tabItem { Label("Games", systemImage: "gamecontroller") }
            .tag(3)
            
            NavigationStack(path: $coordinator.path) {
                FavoritesView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case let .book(book):
                            ChaptersView(book: book)
                                .navigationBarTitleDisplayMode(.inline)
                        case let .chapter(book, chapter):
                            VersesView(book: book, chapter: chapter)
                                .navigationBarTitleDisplayMode(.inline)
                        case let .reader(book, chapter, startVerse):
                            ReadingView(book: book, chapter: chapter, startVerse: startVerse)
                                .navigationBarTitleDisplayMode(.inline)
                                .font(.system(size: readerFontSize))
                                .toolbar {
                                    if isPad {
                                        ToolbarItemGroup(placement: .topBarTrailing) {
                                            Button {
                                                readerFontSize = max(12, readerFontSize - 1)
                                            } label: {
                                                Image(systemName: "textformat.size.smaller")
                                            }
                                            .accessibilityLabel("Decrease font size")

                                            Button {
                                                readerFontSize = min(30, readerFontSize + 1)
                                            } label: {
                                                Image(systemName: "textformat.size.larger")
                                            }
                                            .accessibilityLabel("Increase font size")
                                        }
                                    }
                                }
                        }
                    }
            }
            .tabItem { Label("Favorites", systemImage: "heart") }
            .tag(4)
            
            NavigationStack(path: $coordinator.path) {
                SearchView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case let .book(book):
                            ChaptersView(book: book)
                                .navigationBarTitleDisplayMode(.inline)
                        case let .chapter(book, chapter):
                            VersesView(book: book, chapter: chapter)
                                .navigationBarTitleDisplayMode(.inline)
                        case let .reader(book, chapter, startVerse):
                            ReadingView(book: book, chapter: chapter, startVerse: startVerse)
                                .navigationBarTitleDisplayMode(.inline)
                                .font(.system(size: readerFontSize))
                                .toolbar {
                                    if isPad {
                                        ToolbarItemGroup(placement: .topBarTrailing) {
                                            Button {
                                                readerFontSize = max(12, readerFontSize - 1)
                                            } label: {
                                                Image(systemName: "textformat.size.smaller")
                                            }
                                            .accessibilityLabel("Decrease font size")

                                            Button {
                                                readerFontSize = min(30, readerFontSize + 1)
                                            } label: {
                                                Image(systemName: "textformat.size.larger")
                                            }
                                            .accessibilityLabel("Increase font size")
                                        }
                                    }
                                }
                        }
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(5)
            
            NavigationStack(path: $coordinator.path) {
                SettingsView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case let .book(book):
                            ChaptersView(book: book)
                                .navigationBarTitleDisplayMode(.inline)
                        case let .chapter(book, chapter):
                            VersesView(book: book, chapter: chapter)
                                .navigationBarTitleDisplayMode(.inline)
                        case let .reader(book, chapter, startVerse):
                            ReadingView(book: book, chapter: chapter, startVerse: startVerse)
                                .navigationBarTitleDisplayMode(.inline)
                                .font(.system(size: readerFontSize))
                                .toolbar {
                                    if isPad {
                                        ToolbarItemGroup(placement: .topBarTrailing) {
                                            Button {
                                                readerFontSize = max(12, readerFontSize - 1)
                                            } label: {
                                                Image(systemName: "textformat.size.smaller")
                                            }
                                            .accessibilityLabel("Decrease font size")

                                            Button {
                                                readerFontSize = min(30, readerFontSize + 1)
                                            } label: {
                                                Image(systemName: "textformat.size.larger")
                                            }
                                            .accessibilityLabel("Increase font size")
                                        }
                                    }
                                }
                        }
                    }
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(6)
        }
        .environmentObject(coordinator)
        .environmentObject(journalComposer)
        .preferredColorScheme(preferredScheme)
        .dynamicTypeSize(preferredDynamicType ?? .large)
        .font(preferredCustomFontName != nil ? .custom(preferredCustomFontName!, size: baseFontSize) : .system(size: baseFontSize))
        .fontDesign(preferredFontDesign ?? .default)
        .onAppear {
            // One-time cleanup of deprecated app time keys
            if !didCleanupAppTimeKeys {
                UserDefaults.standard.removeObject(forKey: "appTotalActiveSeconds")
                UserDefaults.standard.removeObject(forKey: "appActiveStart")
                didCleanupAppTimeKeys = true
            }
            // Ensure Focus Live Activity is visible on Lock Screen/Dynamic Island across the app
            if let shared = UserDefaults(suiteName: "group.bible.app") {
                let title = shared.string(forKey: "focusTitle")?.trimmingCharacters(in: .whitespacesAndNewlines)
                let body = shared.string(forKey: "focusBody")?.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasContent = ((title?.isEmpty == false) || (body?.isEmpty == false))
                if hasContent {
                    PrayerTimerActivityController.shared.ensureFocusIfNone(title: title?.isEmpty == true ? nil : title, body: body?.isEmpty == true ? nil : body)
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
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
