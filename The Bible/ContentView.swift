//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = NavigationCoordinator()
    @State private var selectedTab: Int = 0
    
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = ColorSchemePreference.system.rawValue
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    
    @State private var rootSize: CGSize = .zero
    
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appTotalActiveSeconds") private var appTotalActiveSeconds: Int = 0
    @AppStorage("appActiveStart") private var appActiveStart: Double = 0
    
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
                            }
                        }
                }
                .tabItem { Label("Bible", systemImage: "book") }
                .tag(1)
            }
            
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
                        }
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(2)
            
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
                        }
                    }
            }
            .tabItem { Label("Favorites", systemImage: "heart") }
            .tag(3)
            
            JournalListView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(4)
            
            NavigationStack(path: $coordinator.path) {
                GamesView()
            }
            .tabItem { Label("Games", systemImage: "gamecontroller") }
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
                        }
                    }
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(6)
        }
        .environmentObject(coordinator)
        .preferredColorScheme(preferredScheme)
        .dynamicTypeSize(preferredDynamicType ?? .large)
        .font(preferredCustomFontName != nil ? .custom(preferredCustomFontName!, size: baseFontSize) : .system(size: baseFontSize))
        .fontDesign(preferredFontDesign ?? .default)
        .onAppear {
            if appActiveStart == 0 {
                appActiveStart = Date().timeIntervalSince1970
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
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if appActiveStart == 0 {
                    appActiveStart = Date().timeIntervalSince1970
                }
            case .inactive, .background:
                if appActiveStart > 0 {
                    let start = Date(timeIntervalSince1970: appActiveStart)
                    let delta = max(0, Int(Date().timeIntervalSince(start)))
                    appTotalActiveSeconds += delta
                    appActiveStart = 0
                }
            @unknown default:
                break
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { rootSize = proxy.size }
                    .onChange(of: proxy.size) { _, newSize in rootSize = newSize }
            }
        )
        .onOpenURL { url in
            guard url.scheme == "thebible" else { return }
            switch url.host?.lowercased() {
            case "timer":
                selectedTab = 0
                UserDefaults.standard.set("timer", forKey: "prayerMode")
            case "stopwatch":
                selectedTab = 0
                UserDefaults.standard.set("stopwatch", forKey: "prayerMode")
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
