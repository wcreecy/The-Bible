import SwiftUI

extension Notification.Name {
    static let openGameStart = Notification.Name("openGameStart")
}

private enum GameRoute: String, CaseIterable, Hashable, Identifiable {
    case quiz
    case hangman
    case beatTheClock
    case verseMatch
    case favoritesFlashcards
    case bookOrder
    case wordSearch
    case whoAmI
    case wordle

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .quiz: "Bible Quiz"
        case .hangman: "Hangman"
        case .beatTheClock: "Beat the Clock"
        case .verseMatch: "Verse Match"
        case .favoritesFlashcards: "Favorites Flashcards"
        case .bookOrder: "Book Order"
        case .wordSearch: "Word Search"
        case .whoAmI: "Who am I?"
        case .wordle: "WORD"
        }
    }

    var displayName: String {
        switch self {
        case .quiz: "Bible Quiz"
        case .hangman: "Hangman"
        case .beatTheClock: "Beat the Clock"
        case .verseMatch: "Verse Match"
        case .favoritesFlashcards: "Favorites Flashcards"
        case .bookOrder: "Book Order"
        case .wordSearch: "Word Search"
        case .whoAmI: "Who am I?"
        case .wordle: "WORD"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .quiz: "Test your Bible knowledge"
        case .hangman: "Guess a person, place, or book"
        case .beatTheClock: "Name a book before time runs out"
        case .verseMatch: "Match each verse to its reference"
        case .favoritesFlashcards: "Practice your saved verses"
        case .bookOrder: "Put Bible books in order"
        case .wordSearch: "Find hidden words from a verse"
        case .whoAmI: "Match names and descriptions"
        case .wordle: "Solve today's five-letter word"
        }
    }

    var systemImage: String {
        switch self {
        case .quiz: "questionmark.circle.fill"
        case .hangman: "text.word.spacing"
        case .beatTheClock: "hourglass"
        case .verseMatch: "text.quote"
        case .favoritesFlashcards: "rectangle.portrait.on.rectangle.portrait"
        case .bookOrder: "list.number"
        case .wordSearch: "square.grid.3x3.topleft.filled"
        case .whoAmI: "person.text.rectangle"
        case .wordle: "square.grid.3x3.fill"
        }
    }

    var tint: Color {
        switch self {
        case .quiz: .blue
        case .hangman: .teal
        case .beatTheClock: .indigo
        case .verseMatch: .orange
        case .favoritesFlashcards: .pink
        case .bookOrder: .purple
        case .wordSearch: .green
        case .whoAmI: .brown
        case .wordle: .mint
        }
    }
}

private enum GameCategory: String, CaseIterable, Identifiable {
    case knowledge
    case words
    case memory
    case speed

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .knowledge: "Knowledge"
        case .words: "Words"
        case .memory: "Memory"
        case .speed: "Speed"
        }
    }

    var routes: [GameRoute] {
        switch self {
        case .knowledge: [.quiz, .whoAmI]
        case .words: [.wordle, .hangman, .wordSearch]
        case .memory: [.verseMatch, .bookOrder, .favoritesFlashcards]
        case .speed: [.beatTheClock]
        }
    }
}

private struct DailyWordResult: Codable {
    let won: Bool
    let guesses: Int
    let elapsed: Int
    let word: String
}

struct GamesView: View {
    @State private var selection: GameRoute?
    @State private var isPresentingProgrammatic = false
    @State private var todayWordResult: DailyWordResult?
    @State private var refreshToken = 0

    @AppStorage("favoriteGameRoutes") private var favoriteRoutesRaw = ""
    @AppStorage("recentGameRoutes") private var recentRoutesRaw = ""

    private var favoriteRoutes: [GameRoute] {
        let favorites = Set(favoriteRoutesRaw.split(separator: ",").compactMap { GameRoute(rawValue: String($0)) })
        return GameRoute.allCases.filter(favorites.contains)
    }

    private var recentRoutes: [GameRoute] {
        recentRoutesRaw.split(separator: ",").compactMap { GameRoute(rawValue: String($0)) }
    }

    private var statsByName: [String: GameStats.GameBreakdown.Entry] {
        Dictionary(uniqueKeysWithValues: GameStats.shared.breakdownSnapshot().entries.map { ($0.name, $0) })
    }

    var body: some View {
        List {
            DailyChallengeSection(
                route: .wordle,
                result: todayWordResult,
                progress: progressText(for: .wordle)
            )

            GameCollectionSection(
                title: "Recently Played",
                emptyMessage: "Games you play will appear here.",
                routes: recentRoutes,
                favoriteRoutes: Set(favoriteRoutes),
                progress: progressText,
                toggleFavorite: toggleFavorite
            )

            GameCollectionSection(
                title: "Favorites",
                emptyMessage: "Tap a star to keep a game close at hand.",
                routes: favoriteRoutes,
                favoriteRoutes: Set(favoriteRoutes),
                progress: progressText,
                toggleFavorite: toggleFavorite
            )

            ForEach(GameCategory.allCases) { category in
                GameCollectionSection(
                    title: category.title,
                    routes: category.routes,
                    favoriteRoutes: Set(favoriteRoutes),
                    progress: progressText,
                    toggleFavorite: toggleFavorite
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("Games")
        .navigationDestination(for: GameRoute.self) { route in
            destination(for: route)
                .onAppear { recordRecentlyPlayed(route) }
        }
        .navigationDestination(isPresented: $isPresentingProgrammatic) {
            if let selection {
                destination(for: selection)
                    .onAppear { recordRecentlyPlayed(selection) }
                    .onDisappear { self.selection = nil }
            }
        }
        .onAppear {
            selection = nil
            loadTodayWordResult()
            seedRecentGameIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openGameStart)) { note in
            guard let name = note.userInfo?["gameName"] as? String,
                  let route = GameRoute.allCases.first(where: { $0.displayName == name }) else { return }
            selection = route
            isPresentingProgrammatic = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            refreshToken &+= 1
            loadTodayWordResult()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshToken &+= 1
            loadTodayWordResult()
        }
    }

    @ViewBuilder
    private func destination(for route: GameRoute) -> some View {
        switch route {
        case .quiz: QuizView()
        case .hangman: HangmanGameView()
        case .beatTheClock: BeatTheClockGameView()
        case .verseMatch: VerseMatchGameView()
        case .favoritesFlashcards: FavoritesFlashcardsGameView()
        case .bookOrder: BookOrderGameView()
        case .wordSearch: WordSearchGameView()
        case .whoAmI: WhoAmIGameView()
        case .wordle: WordleView()
        }
    }

    private func progressText(for route: GameRoute) -> String {
        _ = refreshToken

        if route == .wordle, let result = todayWordResult {
            return result.won ? "Solved in \(result.guesses)/6" : "Try again tomorrow"
        }

        guard let entry = statsByName[route.displayName], entry.answered > 0 else {
            return "Not played"
        }

        let accuracy = Int((Double(entry.correct) / Double(entry.answered) * 100).rounded())
        if let bestStreak = entry.bestStreak, bestStreak > 0 {
            return "\(accuracy)% · Best \(bestStreak)"
        }
        return "\(accuracy)% · \(entry.answered) played"
    }

    private func toggleFavorite(_ route: GameRoute) {
        var favorites = Set(favoriteRoutesRaw.split(separator: ",").compactMap { GameRoute(rawValue: String($0)) })
        if favorites.contains(route) {
            favorites.remove(route)
        } else {
            favorites.insert(route)
        }
        favoriteRoutesRaw = GameRoute.allCases.filter(favorites.contains).map(\.rawValue).joined(separator: ",")
    }

    private func recordRecentlyPlayed(_ route: GameRoute) {
        var routes = recentRoutes.filter { $0 != route }
        routes.insert(route, at: 0)
        recentRoutesRaw = routes.prefix(3).map(\.rawValue).joined(separator: ",")
    }

    private func seedRecentGameIfNeeded() {
        guard recentRoutes.isEmpty,
              let lastPlayedName = GameStats.shared.lastPlayedGameName,
              let route = GameRoute.allCases.first(where: { $0.displayName == lastPlayedName }) else { return }
        recentRoutesRaw = route.rawValue
    }

    private func loadTodayWordResult() {
        let today = GameStats.localDayKey(for: Date())
        guard let data = UserDefaults.standard.data(forKey: "wordleDailyResultMap"),
              let results = try? JSONDecoder().decode([String: DailyWordResult].self, from: data) else {
            todayWordResult = nil
            return
        }
        todayWordResult = results[today]
    }
}

private struct DailyChallengeSection: View {
    let route: GameRoute
    let result: DailyWordResult?
    let progress: String

    var body: some View {
        Section("Daily Challenge") {
            NavigationLink(value: route) {
                HStack(spacing: 14) {
                    Image(systemName: result == nil ? "sparkles" : "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(result == nil ? .orange : .green)
                        .frame(width: 36, height: 36)
                        .background(.thinMaterial, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.title)
                            .font(.headline)
                        Text(result == nil ? "A new Bible word is ready" : progress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if result == nil {
                        Text("Play")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

private struct GameCollectionSection: View {
    let title: LocalizedStringResource
    var emptyMessage: LocalizedStringResource?
    let routes: [GameRoute]
    let favoriteRoutes: Set<GameRoute>
    let progress: (GameRoute) -> String
    let toggleFavorite: (GameRoute) -> Void

    init(
        title: LocalizedStringResource,
        emptyMessage: LocalizedStringResource? = nil,
        routes: [GameRoute],
        favoriteRoutes: Set<GameRoute>,
        progress: @escaping (GameRoute) -> String,
        toggleFavorite: @escaping (GameRoute) -> Void
    ) {
        self.title = title
        self.emptyMessage = emptyMessage
        self.routes = routes
        self.favoriteRoutes = favoriteRoutes
        self.progress = progress
        self.toggleFavorite = toggleFavorite
    }

    var body: some View {
        Section {
            if routes.isEmpty, let emptyMessage {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(routes) { route in
                    GameNavigationRow(
                        route: route,
                        progress: progress(route),
                        isFavorite: favoriteRoutes.contains(route),
                        toggleFavorite: { toggleFavorite(route) }
                    )
                }
            }
        } header: {
            Text(title)
        }
    }
}

private struct GameNavigationRow: View {
    let route: GameRoute
    let progress: String
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            NavigationLink(value: route) {
                HStack(spacing: 12) {
                    Image(systemName: route.systemImage)
                        .font(.title3)
                        .foregroundStyle(route.tint)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(route.title)
                            .font(.headline)
                        Text(route.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(progress)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 4)
            }

            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }
}

#Preview {
    NavigationStack { GamesView() }
}
