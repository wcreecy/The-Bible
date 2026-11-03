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
                systemImage: "textformat.abc",
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
        .onChange(of: AppDataChanges.shared.gameStats) {
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
            case .bookOrder: BookOrderGameView()
            case .wordSearch: WordSearchGameView()
            case .scramble: ScrambleGameView()
            case .crossword: CrosswordGameView()
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
            reviewProgress = MissedGameQuestionStore.Entry.Game.reviewableCases.map { game in
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
              let results = PersistedDecoding.decode([String: DailyWordResult].self, from: data, key: "wordleDailyResultMap", keepingUnreadableIn: .standard) else {
            return nil
        }
        return results[GameStats.localDayKey(for: Date())]
    }
}

#Preview {
    NavigationStack {
        GamesView(path: .constant(NavigationPath()))
    }
}
