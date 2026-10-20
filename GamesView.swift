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

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .quiz: "Bible Quiz"
        case .hangman: "Hangman"
        case .beatTheClock: "Beat the Clock"
        case .verseMatch: "Verse Match"
        case .bookOrder: "Book Order"
        case .wordSearch: "Word Search"
        case .whoAmI: "Who am I?"
        case .wordle: "WORD"
        case .trivia: "Bible Trivia"
        }
    }

    var displayName: String {
        switch self {
        case .quiz: "Bible Quiz"
        case .hangman: "Hangman"
        case .beatTheClock: "Beat the Clock"
        case .verseMatch: "Verse Match"
        case .bookOrder: "Book Order"
        case .wordSearch: "Word Search"
        case .whoAmI: "Who am I?"
        case .wordle: "WORD"
        case .trivia: "Bible Trivia"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .quiz: "Build recall of Bible facts and passages"
        case .hangman: "Strengthen recognition of people, places, and books"
        case .beatTheClock: "Practice quick recall of Bible books"
        case .verseMatch: "Connect Scripture passages with their references"
        case .bookOrder: "Learn the sequence of the Bible’s books"
        case .wordSearch: "Notice key words in Scripture"
        case .whoAmI: "Learn people and their roles in the Bible"
        case .wordle: "Return each day for a short Scripture word challenge"
        case .trivia: "Answer Bible knowledge questions with Scripture support"
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
        case .learn: [.beatTheClock, .quiz, .trivia, .bookOrder, .verseMatch, .whoAmI]
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

struct GamesView: View {
    @Binding var path: NavigationPath

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Favorite.createdAt, order: .reverse) private var favorites: [Favorite]

    /// Row progress text, rebuilt only when stats change. Building it reads about a hundred
    /// stored values, so it must not run on every redraw.
    @State private var progressByRoute: [GameRoute: String] = [:]
    @State private var verseToRememberOffset = 0

    private var todayChallengeStore: TodayChallengeStore { .shared }

    private var verseToRemember: HomeVerseRef? {
        guard !favorites.isEmpty else { return nil }
        // Count local days; `ordinality(of: .day, in: .era)` counts in UTC and would change
        // the verse in the evening rather than at midnight.
        let calendar = Calendar.current
        let reference = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)) ?? .distantPast
        let day = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: reference),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        let favorite = favorites[(day + verseToRememberOffset) % favorites.count]
        return HomeVerseRef(
            bookName: favorite.bookName,
            chapterNumber: favorite.chapterNumber,
            verseNumber: favorite.verseNumber,
            verseText: favorite.verseText
        )
    }

    private var recommendation: GameRecommendation {
        if let challenge = todayChallengeStore.challenges.first(where: {
            $0.kind == .playGame && !$0.isCompleted && $0.gameName != nil
        }), let route = GameRoute.allCases.first(where: { $0.displayName == challenge.gameName }) {
            return GameRecommendation(
                title: "Continue today’s challenge",
                detail: challenge.title,
                systemImage: "checklist",
                destination: .game(route)
            )
        }

        if let studyRecommendation {
            return GameRecommendation(
                title: "Study \(studyRecommendation.bookName)",
                detail: "You missed \(studyRecommendation.missedCount) questions about this book. Explore its overview.",
                systemImage: "text.book.closed",
                destination: .bookOverview(studyRecommendation.bookName)
            )
        }

        if !favorites.isEmpty {
            return GameRecommendation(
                title: "Review saved verses",
                detail: "Practice matching verses you’ve saved with their references.",
                systemImage: "bookmark.fill",
                destination: .game(.verseMatch)
            )
        }

        return GameRecommendation(
            title: "Start with Bible Quiz",
            detail: "Build a baseline and get a personalized recommendation as you play.",
            systemImage: "questionmark.circle.fill",
            destination: .game(.quiz)
        )
    }

    private var studyRecommendation: (bookName: String, missedCount: Int)? {
        let defaults = UserDefaults.standard
        let answeredKeys = ["quizPerBookAnsweredMap", "versematchPerBookAnsweredMap"]
        let correctKeys = ["quizPerBookCorrectMap", "versematchPerBookCorrectMap"]
        var totals: [String: (answered: Int, correct: Int)] = [:]

        for (answeredKey, correctKey) in zip(answeredKeys, correctKeys) {
            let answered = (try? JSONDecoder().decode([String: Int].self, from: defaults.data(forKey: answeredKey) ?? Data())) ?? [:]
            let correct = (try? JSONDecoder().decode([String: Int].self, from: defaults.data(forKey: correctKey) ?? Data())) ?? [:]
            for (book, count) in answered {
                totals[book, default: (0, 0)].answered += count
                totals[book, default: (0, 0)].correct += correct[book] ?? 0
            }
        }

        guard let weakestBook = totals
            .map({ (bookName: $0.key, answered: $0.value.answered, missedCount: max(0, $0.value.answered - $0.value.correct)) })
            .filter({ $0.answered >= 3 && $0.missedCount >= 3 })
            .max(by: { lhs, rhs in
                if lhs.missedCount != rhs.missedCount {
                    return lhs.missedCount < rhs.missedCount
                }
                return lhs.bookName.localizedStandardCompare(rhs.bookName) == .orderedAscending
            }) else {
            return nil
        }

        return (weakestBook.bookName, weakestBook.missedCount)
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
        .onAppear {
            refreshProgress()
            todayChallengeStore.refresh()
            openPendingGameIfNeeded()
        }
        .onChange(of: AppRouter.shared.latest) { _, request in
            if request?.destination == .gameStart {
                openPendingGameIfNeeded()
            }
        }
        .onNotification(.gameStatsExternallyUpdated) {
            refreshProgress()
        }
        .onNotification(UIApplication.willEnterForegroundNotification) {
            refreshProgress()
        }
    }

    private var gameCollectionCard: some View {
        GameCollectionCard(
            groups: GameLearningGroup.allCases,
            usesExpandedLayout: horizontalSizeClass == .regular,
            progress: { progressByRoute[$0] ?? "Not played" },
            recommendation: recommendation,
            onSelect: present,
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
            }
        }
    }

    private func refreshProgress() {
        let statsByName = Dictionary(
            GameStats.shared.breakdownSnapshot().entries.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let todayWordResult = loadTodayWordResult()
        progressByRoute = Dictionary(uniqueKeysWithValues: GameRoute.allCases.map { route in
            (route, progressText(for: route, entry: statsByName[route.displayName], todayWordResult: todayWordResult))
        })
    }

    private func progressText(
        for route: GameRoute,
        entry: GameStats.GameBreakdown.Entry?,
        todayWordResult: DailyWordResult?
    ) -> String {
        if route == .wordle, let result = todayWordResult {
            return result.won ? "Solved in \(result.guesses)/6" : "Try again tomorrow"
        }

        guard let entry, entry.answered > 0 else {
            return "Not played"
        }

        let accuracy = Int((Double(entry.correct) / Double(entry.answered) * 100).rounded())
        let bestStreak = max(0, entry.bestStreak ?? 0)
        if route == .trivia || bestStreak > 0 {
            return "\(accuracy)% · Best \(bestStreak)"
        }
        return "\(accuracy)% · \(entry.answered) played"
    }

    private func present(_ route: GameRoute) {
        path.append(route)
    }

    private func selectRecommendation(_ destination: GameRecommendationDestination) {
        switch destination {
        case .game(let route):
            present(route)
        case .bookOverview(let bookName):
            UserDefaults.standard.set(bookName, forKey: "lastStudiedBook")
            UserDefaults.standard.set(true, forKey: "openLastStudiedBookOverview")
            AppRouter.shared.open(.bibleStudy)
        }
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
    let usesExpandedLayout: Bool
    let progress: (GameRoute) -> String
    let recommendation: GameRecommendation
    let onSelect: (GameRoute) -> Void
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

            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(.subheadline.weight(.bold))
                        Text(group.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)
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
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .topLeading
        )
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }
}

private enum GameRecommendationDestination {
    case game(GameRoute)
    case bookOverview(String)

    var accessibilityHint: String {
        switch self {
        case .game(let route):
            "Opens \(route.displayName)"
        case .bookOverview(let bookName):
            "Opens the \(bookName) book overview"
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
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: recommendation.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended for you")
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

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(recommendation.destination.accessibilityHint)
    }
}

private struct GameNavigationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let route: GameRoute
    let progress: String
    let usesExpandedLayout: Bool
    let onSelect: () -> Void

    var body: some View {
        Group {
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
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onSelect()
        }
    }
}

private struct GameStandardRow: View {
    let route: GameRoute
    let progress: String
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

            Text(progress)
                .font((usesExpandedLayout ? Font.footnote : Font.caption).weight(.medium))
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
                .font(.caption)
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
