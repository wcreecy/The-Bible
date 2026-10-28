import SwiftUI
import SwiftData

struct GameNavigationTitle: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: tint.opacity(0.22), radius: 5, y: 3)

            Text(title)
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
    }
}

/// Opens a game from elsewhere in the app (for example a Today challenge).
/// The request is held until the Games screen consumes it, because the Games tab
/// may not have been created yet when the request is made.
@MainActor
enum GameLaunchRequest {
    private(set) static var pendingGameName: String?

    /// Switches to the Games tab and opens the game with the given display name.
    static func open(gameName: String) {
        pendingGameName = gameName
        AppRouter.shared.open(.gameStart)
    }

    static func consume() -> String? {
        defer { pendingGameName = nil }
        return pendingGameName
    }
}

private enum GameRoute: String, CaseIterable, Hashable, Identifiable {
    case quiz
    case hangman
    case beatTheClock
    case verseMatch
    case bookOrder
    case wordSearch
    case whoAmI
    case wordle
    case trivia
    case reviewRound

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .quiz: "Quiz"
        case .hangman: "Hangman"
        case .beatTheClock: "Countdown"
        case .verseMatch: "Verses"
        case .bookOrder: "Book Order"
        case .wordSearch: "Word Search"
        case .whoAmI: "Who?"
        case .wordle: "WORD"
        case .trivia: "Trivia"
        case .reviewRound: "Review Round"
        }
    }

    var displayName: String {
        switch self {
        case .quiz: "Quiz"
        case .hangman: "Hangman"
        case .beatTheClock: "Countdown"
        case .verseMatch: "Verses"
        case .bookOrder: "Book Order"
        case .wordSearch: "Word Search"
        case .whoAmI: "Who?"
        case .wordle: "WORD"
        case .trivia: "Trivia"
        case .reviewRound: "Review Round"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .quiz: "Bible facts"
        case .hangman: "People, places & books"
        case .beatTheClock: "Beat the clock"
        case .verseMatch: "What verse is this?"
        case .bookOrder: "Put books in order"
        case .wordSearch: "Find the words"
        case .whoAmI: "Name the person"
        case .wordle: "5 letters, 6 tries"
        case .trivia: "Bible Trivia"
        case .reviewRound: "Previously missed questions"
        }
    }

    var systemImage: String {
        switch self {
        case .quiz: "questionmark.circle.fill"
        case .hangman: "text.word.spacing"
        case .beatTheClock: "hourglass"
        case .verseMatch: "text.quote"
        case .bookOrder: "list.number"
        case .wordSearch: "square.grid.3x3.topleft.filled"
        case .whoAmI: "person.text.rectangle"
        case .wordle: "square.grid.3x3.fill"
        case .trivia: "questionmark.text.page.fill"
        case .reviewRound: "arrow.clockwise.heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .quiz: .blue
        case .hangman: .teal
        case .beatTheClock: .indigo
        case .verseMatch: .orange
        case .bookOrder: .purple
        case .wordSearch: .green
        case .whoAmI: .brown
        case .wordle: .mint
        case .trivia: .cyan
        case .reviewRound: .purple
        }
    }
}

private enum GameLearningGroup: CaseIterable, Identifiable {
    case daily
    case learn
    case wordGames

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .daily: "Daily"
        case .learn: "Learn"
        case .wordGames: "Word Games"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .daily: "Short practices to return to each day."
        case .learn: "Build familiarity with people, places, and Bible knowledge."
        case .wordGames: "Find and recognize Bible words."
        }
    }

    var routes: [GameRoute] {
        switch self {
        case .daily: [.wordle]
        case .learn: [.bookOrder, .beatTheClock, .quiz, .trivia, .verseMatch, .whoAmI]
        case .wordGames: [.hangman, .wordSearch]
        }
    }
}

private struct DailyWordResult: Codable {
    let won: Bool
    let guesses: Int
    let elapsed: Int
    let word: String
}

private enum GameProgress: Equatable {
    case standard(String)
    case dailyWord(word: String, won: Bool)
}

private enum ReviewRoundDestination: Hashable {
    case game(String)
}

private struct ReviewRoundProgress: Identifiable {
    let game: MissedGameQuestionStore.Entry.Game
    let count: Int

    var id: String { game.rawValue }
    var isReady: Bool { count >= 10 }

    var title: LocalizedStringResource {
        switch game {
        case .beatTheClock: "Beat the Clock"
        case .bibleQuiz: "Quiz"
        case .bibleTrivia: "Trivia"
        case .verseMatch: "Verses"
        case .whoAmI: "Who?"
        }
    }
}

struct GamesView: View {
    @Binding var path: NavigationPath

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Favorite.createdAt, order: .reverse) private var favorites: [Favorite]

    /// Row progress text, rebuilt only when stats change. Building it reads about a hundred
    /// stored values, so it must not run on every redraw.
    @State private var progressByRoute: [GameRoute: GameProgress] = [:]
    @State private var reviewProgress: [ReviewRoundProgress] = []
    /// Recommendation inputs include decoded UserDefaults data, so cache the finished value
    /// instead of rebuilding it whenever SwiftUI reevaluates this screen.
    @State private var cachedRecommendation = GameRecommendation(
        title: "Start with Trivia",
        detail: "Build a baseline and get a personalized recommendation as you play.",
        systemImage: "questionmark.text.page.fill",
        destination: .game(.trivia)
    )
    @State private var verseToRememberOffset = 0
    @State private var recommendationPromptDayKey = ""
    @State private var promptedGameRoutes: Set<String> = []

    private var todayChallengeStore: TodayChallengeStore { .shared }

    private var verseToRemember: HomeVerseRef? {
        verseToRemember(from: favorites, offset: verseToRememberOffset)
    }

    /// Selects a stable daily favorite without building a nested map-and-sort expression.
    private func verseToRemember(from favorites: [Favorite], offset: Int) -> HomeVerseRef? {
        guard !favorites.isEmpty else { return nil }

        let calendar = Calendar.current
        let reference = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)) ?? .distantPast
        let day = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: reference),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        var ranked: [(score: UInt64, key: String, favorite: Favorite)] = []
        ranked.reserveCapacity(favorites.count)

        for favorite in favorites {
            let key = "\(favorite.bookName)|\(favorite.chapterNumber)|\(favorite.verseNumber)"
            let score = Self.stableHash("\(day)|\(key)")
            ranked.append((score: score, key: key, favorite: favorite))
        }

        ranked.sort {
            $0.score != $1.score ? $0.score > $1.score : $0.key < $1.key
        }

        let favorite = ranked[offset % ranked.count].favorite
        return HomeVerseRef(
            bookName: favorite.bookName,
            chapterNumber: favorite.chapterNumber,
            verseNumber: favorite.verseNumber,
            verseText: favorite.verseText
        )
    }

    /// FNV-1a. Swift's `Hasher` is reseeded every launch, so it can't give a stable daily pick.
    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return hash
    }

    private func makeRecommendation() -> GameRecommendation {
        if let challenge = todayChallengeStore.challenges.first(where: {
            $0.kind == .playGame && !$0.isCompleted && $0.gameName != nil
        }), let route = GameRoute.allCases.first(where: { $0.displayName == challenge.gameName }),
           !isPrompted(route) {
            return GameRecommendation(
                title: "Continue today’s challenge",
                detail: challenge.title,
                systemImage: "checklist",
                destination: .game(route)
            )
        }

        let breakdown = GameStats.shared.breakdownSnapshot()
        let hasPlayedAGame = breakdown.totalAnswered > 0

        if hasPlayedAGame, loadTodayWordResult() == nil, !isPrompted(.wordle) {
            return GameRecommendation(
                title: "Play today’s WORD",
                detail: "Solve today’s five-letter Bible word.",
                systemImage: "square.grid.3x3.fill",
                destination: .game(.wordle)
            )
        }

        if !isPrompted(.reviewRound), !MissedGameQuestionStore.shared.reviewableGames().isEmpty {
            return GameRecommendation(
                title: "Review missed questions",
                detail: "Practice questions you previously missed.",
                systemImage: "arrow.clockwise.heart.fill",
                destination: .game(.reviewRound)
            )
        }

        if hasPlayedAGame,
           let route = leastPlayedRoute(in: breakdown.entries) {
            return GameRecommendation(
                title: "Try something new",
                detail: "You haven’t played \(route.displayName) yet.",
                systemImage: "sparkles",
                destination: .game(route)
            )
        }

        if hasPlayedAGame,
           let name = GameStats.shared.lastPlayedGameName,
           let route = GameRoute.allCases.first(where: { $0.displayName == name }),
           !isPrompted(route) {
            return GameRecommendation(
                title: "Play \(route.displayName) again",
                detail: "Continue with the game you played most recently.",
                systemImage: "arrow.clockwise",
                destination: .game(route)
            )
        }

        if !isPrompted(.trivia) {
            return GameRecommendation(
                title: "Start with Trivia",
                detail: "Build a baseline and get a personalized recommendation as you play.",
                systemImage: "questionmark.text.page.fill",
                destination: .game(.trivia)
            )
        }

        let fallbackRoute = GameRoute.allCases.first(where: { route in
            route != .reviewRound && !isPrompted(route)
        }) ?? .trivia
        return GameRecommendation(
            title: "Keep playing",
            detail: "Try \(fallbackRoute.displayName) next.",
            systemImage: fallbackRoute.systemImage,
            destination: .game(fallbackRoute)
        )
    }

    private func leastPlayedRoute(in entries: [GameStats.GameBreakdown.Entry]) -> GameRoute? {
        guard let unplayedGame = entries.first(where: { entry in
            guard entry.answered == 0,
                  let route = GameRoute.allCases.first(where: { $0.displayName == entry.name }) else {
                return false
            }
            return !isPrompted(route)
        }) else {
            return nil
        }
        return GameRoute.allCases.first(where: { $0.displayName == unplayedGame.name })
    }

    private func isPrompted(_ route: GameRoute) -> Bool {
        promptedGameRoutes.contains(route.rawValue)
    }

    var body: some View {
        List {
            Section {
                if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: 16) {
                        gameCollectionCard

                        verseToRememberCard
                    }
                } else {
                    VStack(spacing: 16) {
                        gameCollectionCard
                        verseToRememberCard
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("Games")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: GameRoute.self) { route in
            destination(for: route)
        }
        .navigationDestination(for: ReviewRoundDestination.self) { destination in
            switch destination {
            case .game(let rawValue):
                ReviewRoundView(reviewGameRawValue: rawValue)
            }
        }
        .onAppear {
            todayChallengeStore.refresh()
            refreshPromptCycleIfNeeded()
            refreshProgress()
            openPendingGameIfNeeded()
        }
        .onChange(of: favorites.count) {
            cachedRecommendation = makeRecommendation()
        }
        .onChange(of: AppRouter.shared.latest) { _, request in
            if request?.destination == .gameStart {
                openPendingGameIfNeeded()
            }
        }
        .onNotification(.gameStatsExternallyUpdated) {
            todayChallengeStore.refresh()
            refreshPromptCycleIfNeeded()
            refreshProgress()
        }
        .onNotification(UIApplication.willEnterForegroundNotification) {
            todayChallengeStore.refresh()
            refreshPromptCycleIfNeeded()
            refreshProgress()
        }
        .task {
            while !Task.isCancelled {
                let calendar = Calendar.autoupdatingCurrent
                let now = Date()
                let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
                let wait = max(1, nextDay.timeIntervalSince(now))

                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }

                todayChallengeStore.refresh()
                refreshPromptCycleIfNeeded()
                refreshProgress()
            }
        }
    }

    private var gameCollectionCard: some View {
        GameCollectionCard(
            groups: GameLearningGroup.allCases,
            reviewProgress: reviewProgress,
            usesExpandedLayout: horizontalSizeClass == .regular,
            progress: { progressByRoute[$0] ?? .standard("Not played") },
            recommendation: cachedRecommendation,
            onSelect: present,
            onSelectReviewGame: { destination in path.append(destination) },
            onSelectRecommendation: selectRecommendation
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var verseToRememberCard: some View {
        VerseToRememberCard(
            verse: verseToRemember,
            usesExpandedLayout: horizontalSizeClass == .regular,
            canChooseAnother: favorites.count > 1,
            onChooseAnother: {
                verseToRememberOffset += 1
            },
            onOpenVerse: openVerse,
            onOpenFavorites: {
                AppRouter.shared.open(.favorites)
            }
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
            case .bookOrder: BookOrderGameView()
            case .wordSearch: WordSearchGameView()
            case .whoAmI: WhoAmIGameView()
            case .wordle: WordleView()
            case .trivia: BibleTriviaGameView()
            case .reviewRound: ReviewRoundView()
            }
        }
    }

    private func refreshProgress() {
        AppPerformance.measure("GameStatsRefresh") {
            let statsByName = Dictionary(
                GameStats.shared.breakdownSnapshot().entries.map { ($0.name, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let todayWordResult = loadTodayWordResult()
            progressByRoute = Dictionary(uniqueKeysWithValues: GameRoute.allCases.map { route in
                (route, progressText(for: route, entry: statsByName[route.displayName], todayWordResult: todayWordResult))
            })
            reviewProgress = MissedGameQuestionStore.Entry.Game.allCases.map { game in
                ReviewRoundProgress(
                    game: game,
                    count: MissedGameQuestionStore.shared.reviewCount(for: game)
                )
            }
            cachedRecommendation = makeRecommendation()
        }
    }

    private func progressText(
        for route: GameRoute,
        entry: GameStats.GameBreakdown.Entry?,
        todayWordResult: DailyWordResult?
    ) -> GameProgress {
        if route == .wordle, let result = todayWordResult {
            return .dailyWord(word: result.word, won: result.won)
        }

        guard let entry, entry.answered > 0 else {
            return .standard("Not played")
        }

        let accuracy = Int((Double(entry.correct) / Double(entry.answered) * 100).rounded())
        let bestStreak = max(0, entry.bestStreak ?? 0)
        if route == .trivia || bestStreak > 0 {
            return .standard("\(accuracy)% · Best \(bestStreak)")
        }
        return .standard("\(accuracy)% · \(entry.answered) played")
    }

    private func present(_ route: GameRoute) {
        path.append(route)
    }

    private func selectRecommendation(_ destination: GameRecommendationDestination) {
        switch destination {
        case .game(let route):
            recordPromptedRoute(route)
            present(route)
        }
    }

    private func refreshPromptCycleIfNeeded(now: Date = Date()) {
        let todayKey = GameStats.localDayKey(for: now)
        guard recommendationPromptDayKey != todayKey else { return }

        let defaults = UserDefaults.standard
        recommendationPromptDayKey = todayKey
        if defaults.string(forKey: AppStorageKey.gameRecommendationPromptDayV1) == todayKey {
            promptedGameRoutes = Set(
                defaults.stringArray(forKey: AppStorageKey.gameRecommendationPromptedRoutesV1) ?? []
            )
        } else {
            promptedGameRoutes = []
            defaults.set(todayKey, forKey: AppStorageKey.gameRecommendationPromptDayV1)
            defaults.removeObject(forKey: AppStorageKey.gameRecommendationPromptedRoutesV1)
        }
    }

    private func recordPromptedRoute(_ route: GameRoute) {
        refreshPromptCycleIfNeeded()
        promptedGameRoutes.insert(route.rawValue)
        UserDefaults.standard.set(recommendationPromptDayKey, forKey: AppStorageKey.gameRecommendationPromptDayV1)
        UserDefaults.standard.set(
            promptedGameRoutes.sorted(),
            forKey: AppStorageKey.gameRecommendationPromptedRoutesV1
        )
        cachedRecommendation = makeRecommendation()
    }

    /// Opens a game requested from outside the Games tab, replacing any open game.
    private func openPendingGameIfNeeded() {
        guard let name = GameLaunchRequest.consume(),
              let route = GameRoute.allCases.first(where: { $0.displayName == name }) else { return }
        var newPath = NavigationPath()
        newPath.append(route)
        path = newPath
    }

    private func openVerse(_ verse: HomeVerseRef) {
        AppRouter.shared.openBibleReference(
            book: verse.bookName,
            chapter: verse.chapterNumber,
            verse: verse.verseNumber
        )
    }

    private func loadTodayWordResult() -> DailyWordResult? {
        guard let data = UserDefaults.standard.data(forKey: "wordleDailyResultMap"),
              let results = try? JSONDecoder().decode([String: DailyWordResult].self, from: data) else {
            return nil
        }
        return results[GameStats.localDayKey(for: Date())]
    }
}

private struct GameCollectionCard: View {
    let groups: [GameLearningGroup]
    let reviewProgress: [ReviewRoundProgress]
    let usesExpandedLayout: Bool
    let progress: (GameRoute) -> GameProgress
    let recommendation: GameRecommendation
    let onSelect: (GameRoute) -> Void
    let onSelectReviewGame: (ReviewRoundDestination) -> Void
    let onSelectRecommendation: (GameRecommendationDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Games")
                .font(usesExpandedLayout ? .title3.weight(.bold) : .headline)
                .padding(.bottom, usesExpandedLayout ? 12 : 8)

            GameRecommendationRow(recommendation: recommendation) {
                onSelectRecommendation(recommendation.destination)
            }
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.title)
                                .font(.subheadline.weight(.bold))
                            Text(group.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 6)

                        ForEach(group.routes) { route in
                            VStack(spacing: 0) {
                                GameNavigationRow(
                                    route: route,
                                    progress: progress(route),
                                    usesExpandedLayout: usesExpandedLayout,
                                    onSelect: { onSelect(route) }
                                )

                                if route.id != group.routes.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .gameCatalogSectionCard()
                }

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review")
                            .font(.subheadline.weight(.bold))
                        Text("Practice questions you missed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    ReviewRoundStatusRow(
                        progress: reviewProgress,
                        usesExpandedLayout: usesExpandedLayout,
                        onSelectGame: onSelectReviewGame
                    )
                }
                .gameCatalogSectionCard()
            }
            .padding(.top, 10)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .topLeading
        )
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }
}

private struct GameCatalogSectionCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .heroCardSurface()
    }
}

private extension View {
    func gameCatalogSectionCard() -> some View {
        modifier(GameCatalogSectionCardStyle())
    }
}


private enum GameRecommendationDestination {
    case game(GameRoute)

    var accessibilityHint: String {
        switch self {
        case .game(let route):
            "Opens \(route.displayName)"
        }
    }
}

private struct GameRecommendation {
    let title: String
    let detail: String
    let systemImage: String
    let destination: GameRecommendationDestination
}

private struct GameRecommendationRow: View {
    let recommendation: GameRecommendation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: recommendation.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                        .background(Color.purple.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Play next")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(recommendation.title)
                            .font(.subheadline.weight(.bold))
                        Text(recommendation.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label("Play next", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(Color.purple, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(recommendation.destination.accessibilityHint)
        .accessibilityIdentifier("playNextGameButton")
    }
}

private struct ReviewRoundStatusRow: View {
    let progress: [ReviewRoundProgress]
    let usesExpandedLayout: Bool
    let onSelectGame: (ReviewRoundDestination) -> Void

    private var hasEligibleGame: Bool { progress.contains { $0.isReady } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.clockwise.heart.fill")
                    .font(usesExpandedLayout ? .title2 : .title3)
                    .foregroundStyle(.purple)
                    .frame(minWidth: usesExpandedLayout ? 36 : 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Review Round")
                        .font(usesExpandedLayout ? .title3.weight(.semibold) : .headline)
                    Text("Active with 10 missed questions.")
                        .font(usesExpandedLayout ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(progress) { item in
                HStack {
                    Text(item.title)
                        .font(.caption)
                    Spacer()
                    Text("\(item.count) / 10")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(item.isReady ? .purple : .secondary)

                    if item.isReady {
                        Button("Play") {
                            onSelectGame(.game(item.game.rawValue))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, usesExpandedLayout ? 9 : 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasEligibleGame ? "Review Round, ready" : "Review Round, locked")
        .accessibilityHint("Requires 10 replayable missed questions in one game.")
        .accessibilityIdentifier(hasEligibleGame ? "reviewRoundReady" : "reviewRoundLocked")
    }
}

private struct GameNavigationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let route: GameRoute
    let progress: GameProgress
    let usesExpandedLayout: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            if dynamicTypeSize.isAccessibilitySize {
                GameAccessibilityRow(route: route, progress: progress)
            } else {
                GameStandardRow(
                    route: route,
                    progress: progress,
                    usesExpandedLayout: usesExpandedLayout
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : (usesExpandedLayout ? 9 : 4))
        .contentShape(Rectangle())
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gameRoute-\(route.rawValue)")
    }
}

private struct GameStandardRow: View {
    let route: GameRoute
    let progress: GameProgress
    let usesExpandedLayout: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GameRowIcon(route: route, usesExpandedLayout: usesExpandedLayout)

            VStack(alignment: .leading, spacing: 3) {
                Text(route.title)
                    .font(usesExpandedLayout ? .title3.weight(.semibold) : .headline)
                Text(route.subtitle)
                    .font(usesExpandedLayout ? .subheadline : .caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            Spacer(minLength: 8)

            GameProgressLabel(
                progress: progress,
                font: (usesExpandedLayout ? Font.footnote : Font.caption).weight(.medium)
            )
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
    let progress: GameProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                GameRowIcon(route: route)

                Text(route.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(route.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GameProgressLabel(progress: progress, font: .caption.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GameProgressLabel: View {
    let progress: GameProgress
    let font: Font

    var body: some View {
        switch progress {
        case .standard(let text):
            Text(text)
                .font(font)
                .foregroundStyle(.secondary)
        case .dailyWord(let word, let won):
            HStack(spacing: 4) {
                Text(word)
                    .strikethrough(!won)

                Image(systemName: won ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .accessibilityHidden(true)
            }
            .font(font)
            .foregroundStyle(won ? .green : .red)
            .accessibilityLabel(won ? "Today's WORD: \(word), solved" : "Today's WORD: \(word), not solved")
        }
    }
}

private struct GameRowIcon: View {
    let route: GameRoute
    var usesExpandedLayout = false

    var body: some View {
        Image(systemName: route.systemImage)
            .font(usesExpandedLayout ? .title2 : .title3)
            .foregroundStyle(route.tint)
            .frame(minWidth: usesExpandedLayout ? 36 : 28)
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        GamesView(path: .constant(NavigationPath()))
    }
}
