import SwiftUI

struct GameNavigationTitle: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.tint, in: Circle())

            Text(title)
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
    }
}

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

private struct DailyWordResult: Codable {
    let won: Bool
    let guesses: Int
    let elapsed: Int
    let word: String
}

struct GamesView: View {
    @Binding var path: NavigationPath

    @State private var todayWordResult: DailyWordResult?
    @State private var refreshToken = 0

    @AppStorage("recentGameRoutes") private var recentRoutesRaw = ""
    @AppStorage("favoritesFlashcardsPlayCount") private var favoritesFlashcardsPlayCount = 0

    private var allRoutes: [GameRoute] {
        GameRoute.allCases.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private var recentRoutes: [GameRoute] {
        recentRoutesRaw
            .split(separator: ",")
            .compactMap { GameRoute(rawValue: String($0)) }
            .prefix(2)
            .map { $0 }
    }

    private var statsByName: [String: GameStats.GameBreakdown.Entry] {
        Dictionary(uniqueKeysWithValues: GameStats.shared.breakdownSnapshot().entries.map { ($0.name, $0) })
    }

    var body: some View {
        List {
            if !recentRoutes.isEmpty {
                GameCollectionSection(
                    title: "Recently Played",
                    routes: recentRoutes,
                    progress: progressText,
                    onSelect: present
                )
            }

            GameCollectionSection(
                title: "All Games",
                routes: allRoutes,
                progress: progressText,
                onSelect: present
            )
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("Games")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: GameRoute.self) { route in
            destination(for: route)
                .onAppear { recordRecentlyPlayed(route) }
        }
        .onAppear {
            loadTodayWordResult()
            seedRecentGameIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openGameStart)) { note in
            guard let name = note.userInfo?["gameName"] as? String,
                  let route = GameRoute.allCases.first(where: { $0.displayName == name }) else { return }
            path.append(route)
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
        ZStack {
            AppBackgroundView(tab: .games)

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
    }

    private func progressText(for route: GameRoute) -> String {
        _ = refreshToken

        if route == .wordle, let result = todayWordResult {
            return result.won ? "Solved in \(result.guesses)/6" : "Try again tomorrow"
        }

        if route == .favoritesFlashcards, favoritesFlashcardsPlayCount > 0 {
            let unit = favoritesFlashcardsPlayCount == 1 ? "session" : "sessions"
            return "\(favoritesFlashcardsPlayCount) \(unit)"
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

    private func present(_ route: GameRoute) {
        path.append(route)
    }

    private func recordRecentlyPlayed(_ route: GameRoute) {
        var routes = recentRoutes.filter { $0 != route }
        routes.insert(route, at: 0)
        recentRoutesRaw = routes.prefix(2).map(\.rawValue).joined(separator: ",")
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

private struct GameCollectionSection: View {
    let title: LocalizedStringResource
    let routes: [GameRoute]
    let progress: (GameRoute) -> String
    let onSelect: (GameRoute) -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                    .padding(.bottom, 8)

                ForEach(routes) { route in
                    GameNavigationRow(
                        route: route,
                        progress: progress(route),
                        onSelect: { onSelect(route) }
                    )

                    if route.id != routes.last?.id {
                        Divider()
                    }
                }
            }
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

private struct GameNavigationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let route: GameRoute
    let progress: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    GameAccessibilityRow(route: route, progress: progress)
                } else {
                    GameStandardRow(route: route, progress: progress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

private struct GameStandardRow: View {
    let route: GameRoute
    let progress: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GameRowIcon(route: route)

            VStack(alignment: .leading, spacing: 3) {
                Text(route.title)
                    .font(.headline)
                Text(route.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            Spacer(minLength: 8)

            Text(progress)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

private struct GameAccessibilityRow: View {
    let route: GameRoute
    let progress: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                GameRowIcon(route: route)

                Text(route.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(route.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(progress)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GameRowIcon: View {
    let route: GameRoute

    var body: some View {
        Image(systemName: route.systemImage)
            .font(.title3)
            .foregroundStyle(route.tint)
            .frame(minWidth: 28)
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        GamesView(path: .constant(NavigationPath()))
    }
}
