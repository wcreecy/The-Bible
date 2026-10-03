import SwiftUI

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

extension Notification.Name {
    static let openGameStart = Notification.Name("openGameStart")
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
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .quiz: "Test your Bible knowledge"
        case .hangman: "Guess a person, place, or book"
        case .beatTheClock: "Name a book before time runs out"
        case .verseMatch: "Match each verse to its reference"
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
    @State private var isFavoriteLimitAlertPresented = false

    @AppStorage("favoriteGameRoutes") private var favoriteRoutesRaw = ""
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    private var allRoutes: [GameRoute] {
        GameRoute.allCases.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private var favoriteRoutes: [GameRoute] {
        favoriteRoutesRaw
            .split(separator: ",")
            .compactMap { GameRoute(rawValue: String($0)) }
            .prefix(3)
            .map { $0 }
    }

    private var statsByName: [String: GameStats.GameBreakdown.Entry] {
        Dictionary(uniqueKeysWithValues: GameStats.shared.breakdownSnapshot().entries.map { ($0.name, $0) })
    }

    var body: some View {
        List {
            if contextualTipsEnabled {
                ContextualTipView(
                    title: "Favorite your games",
                    message: "Swipe a game left or right to add it to Favorites. Swipe a favorite to remove it, or drag favorites to reorder them.",
                    systemImage: "hand.draw"
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            GameCollectionSection(
                title: "Favorites",
                routes: favoriteRoutes,
                emptyMessage: "Swipe a game in All Games to add up to three favorites.",
                progress: progressText,
                onSelect: present,
                onToggleFavorite: toggleFavorite,
                onMove: moveFavorite
            )

            GameCollectionSection(
                title: "All Games",
                routes: allRoutes,
                favoriteRoutes: Set(favoriteRoutes),
                progress: progressText,
                onSelect: present,
                onToggleFavorite: toggleFavorite
            )
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("Games")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: GameRoute.self) { route in
            destination(for: route)
        }
        .onAppear {
            loadTodayWordResult()
        }
        .alert("Favorite Limit Reached", isPresented: $isFavoriteLimitAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can select up to three favorite games. Remove one before adding another.")
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

    private func toggleFavorite(_ route: GameRoute) {
        var routes = favoriteRoutes

        if let index = routes.firstIndex(of: route) {
            routes.remove(at: index)
        } else {
            guard routes.count < 3 else {
                isFavoriteLimitAlertPresented = true
                return
            }
            routes.append(route)
        }

        favoriteRoutesRaw = routes.map(\.rawValue).joined(separator: ",")
    }

    private func moveFavorite(_ route: GameRoute, to destinationIndex: Int) {
        guard let sourceIndex = favoriteRoutes.firstIndex(of: route),
              sourceIndex != destinationIndex else { return }

        var routes = favoriteRoutes
        let movedRoute = routes.remove(at: sourceIndex)
        let safeDestinationIndex = min(max(destinationIndex, routes.startIndex), routes.endIndex)
        routes.insert(movedRoute, at: safeDestinationIndex)

        withAnimation(.easeInOut(duration: 0.2)) {
            favoriteRoutesRaw = routes.map(\.rawValue).joined(separator: ",")
        }
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
    var emptyMessage: LocalizedStringResource?
    var favoriteRoutes: Set<GameRoute> = []
    let progress: (GameRoute) -> String
    let onSelect: (GameRoute) -> Void
    var onToggleFavorite: ((GameRoute) -> Void)?
    var onMove: ((GameRoute, Int) -> Void)?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                    .padding(.bottom, 8)

                if routes.isEmpty, let emptyMessage {
                    GameFavoritesEmptyView(message: emptyMessage)
                } else {
                    ForEach(routes) { route in
                        VStack(spacing: 0) {
                            if let onMove {
                                ReorderableFavoriteRow(
                                    route: route,
                                    routes: routes,
                                    progress: progress(route),
                                    onSelect: { onSelect(route) },
                                    onRemove: { onToggleFavorite?(route) },
                                    onMove: onMove
                                )
                            } else {
                                GameNavigationRow(
                                    route: route,
                                    progress: progress(route),
                                    onSelect: { onSelect(route) }
                                )
                                .modifier(
                                    GameFavoriteSwipeModifier(
                                        isEnabled: !favoriteRoutes.contains(route),
                                        actionLabel: "Add to Favorites",
                                        systemImage: "star.fill",
                                        tint: .yellow,
                                        action: { onToggleFavorite?(route) }
                                    )
                                )
                            }

                            if route.id != routes.last?.id {
                                Divider()
                            }
                        }
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

private struct ReorderableFavoriteRow: View {
    @GestureState private var dragOffset: CGFloat = 0
    @State private var rowHeight: CGFloat = 64

    let route: GameRoute
    let routes: [GameRoute]
    let progress: String
    let onSelect: () -> Void
    let onRemove: () -> Void
    let onMove: (GameRoute, Int) -> Void

    var body: some View {
        GameNavigationRow(
            route: route,
            progress: progress,
            onSelect: onSelect
        )
        .modifier(
            GameFavoriteSwipeModifier(
                isEnabled: true,
                actionLabel: "Remove from Favorites",
                systemImage: "star.slash.fill",
                tint: .red,
                action: onRemove
            )
        )
        .offset(y: dragOffset)
        .zIndex(dragOffset == 0 ? 0 : 1)
        .simultaneousGesture(reorderGesture)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            rowHeight = max(newHeight, 44)
        }
        .accessibilityAction(named: "Move Up") {
            guard let index = routes.firstIndex(of: route), index > routes.startIndex else { return }
            onMove(route, routes.index(before: index))
        }
        .accessibilityAction(named: "Move Down") {
            guard let index = routes.firstIndex(of: route),
                  routes.index(after: index) < routes.endIndex else { return }
            onMove(route, routes.index(after: index))
        }
    }

    private var reorderGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragOffset) { value, offset, _ in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                offset = value.translation.height
            }
            .onEnded { value in
                guard abs(value.translation.height) > abs(value.translation.width),
                      let sourceIndex = routes.firstIndex(of: route) else { return }

                let indexOffset = Int((value.translation.height / rowHeight).rounded())
                let destinationIndex = min(
                    max(sourceIndex + indexOffset, routes.startIndex),
                    routes.index(before: routes.endIndex)
                )

                guard destinationIndex != sourceIndex else { return }
                onMove(route, destinationIndex)
            }
    }
}

private struct GameFavoritesEmptyView: View {
    let message: LocalizedStringResource

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

private struct GameFavoriteSwipeModifier: ViewModifier {
    private enum DragAxis {
        case horizontal
        case vertical
    }

    @GestureState private var horizontalTranslation: CGFloat = 0
    @State private var dragAxis: DragAxis?
    @State private var isSuppressingTap = false

    let isEnabled: Bool
    let actionLabel: LocalizedStringResource
    let systemImage: String
    let tint: Color
    let action: () -> Void

    private var displayedTranslation: CGFloat {
        guard isEnabled, dragAxis == .horizontal else { return 0 }
        return min(max(horizontalTranslation, -96), 96)
    }

    func body(content: Content) -> some View {
        ZStack {
            if displayedTranslation != 0 {
                tint.opacity(0.9)

                HStack {
                    if displayedTranslation > 0 {
                        swipeActionLabel
                    }

                    Spacer()

                    if displayedTranslation < 0 {
                        swipeActionLabel
                    }
                }
                .padding(.horizontal, 18)
            }

            content
                .allowsHitTesting(!isSuppressingTap)
                .offset(x: displayedTranslation)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .updating($horizontalTranslation) { value, state, _ in
                    guard isEnabled, dragAxis == .horizontal else { return }
                    state = value.translation.width
                }
                .onChanged { value in
                    guard isEnabled else { return }

                    if dragAxis == nil {
                        dragAxis = abs(value.translation.width) > abs(value.translation.height)
                            ? .horizontal
                            : .vertical
                    }

                    guard dragAxis == .horizontal else { return }
                    isSuppressingTap = true
                }
                .onEnded { value in
                    if isEnabled,
                       dragAxis == .horizontal,
                       abs(value.translation.width) > 72 {
                        action()
                    }

                    dragAxis = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        isSuppressingTap = false
                    }
                }
        )
        .accessibilityAction(named: Text(actionLabel)) {
            guard isEnabled else { return }
            action()
        }
    }

    private var swipeActionLabel: some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.headline)
            Text(actionLabel)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .accessibilityHidden(true)
    }
}

private struct GameNavigationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let route: GameRoute
    let progress: String
    let onSelect: () -> Void

    var body: some View {
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GameRowIcon(route: route)

            VStack(alignment: .leading, spacing: 3) {
                Text(route.title)
                    .font(.headline)
                Text(route.subtitle)
                    .font(.caption)
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
