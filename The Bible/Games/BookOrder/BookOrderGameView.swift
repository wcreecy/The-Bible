import SwiftUI

struct BookOrderGameView: View {
    @Environment(\.preferredPencilDoubleTapAction) private var preferredPencilDoubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var preferredPencilSqueezeAction
    @State private var vm = BookOrderGameViewModel()
    /// The Before or After?, Missing Book or Which Section? round being played, if any.
    @State private var quickRound: BookOrderQuickRound?
    @State private var elapsedSeconds: Int = 0
    /// The solve clock only runs while the app is in front, so time away doesn't count.
    @State private var roundClock = GameActiveClock()
    @State private var isAppActive = true
    @State private var isTimerHidden: Bool = false
    @State private var showsPencilActions = false
    @State private var isWide = false
    /// Books missed earlier, for a review round; empty for a normal game.
    private let reviewBooks: [String]

    init(reviewBooks: [String] = []) {
        self.reviewBooks = reviewBooks
    }

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: {
                switch vm.effectiveDifficulty {
                case .easy: .learn
                case .normal: .standard
                case .hard, .fullBible: .challenge
                }
            },
            set: { level in
                vm.difficulty = switch level {
                case .learn: .easy
                case .standard: .normal
                case .challenge: .hard
                }
            }
        )
    }

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    /// The mode to play here: Classic on iPhone plays as Tap in Order.
    private var mode: BookOrderMode { vm.playMode(isWide: isWide) }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if let quickRound {
                    if quickRound.isFinished {
                        ScrollView {
                            GameRoundSummaryView(
                                summary: GameRoundSummary(score: quickRound.session),
                                tint: .purple,
                                canTimeOut: false,
                                resultNote: quickRoundNote(quickRound),
                                onPlayAgain: { startQuickRound(quickRound.mode) },
                                onChangeSettings: { self.quickRound = nil }
                            )
                            .padding()
                        }
                    } else {
                        BookOrderQuickRoundView(round: quickRound)
                    }
                } else if !vm.started {
                    setupScreen
                } else if mode == .classic {
                    iPadGameBoard(availableHeight: geometry.size.height)
                } else {
                    tapBoard
                }
            }
            .onAppear { isWide = geometry.size.width >= 700 }
            .onChange(of: geometry.size.width) { _, width in isWide = width >= 700 }
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.started || quickRound != nil {
                    GameNavigationTitle(title: "Book Order", systemImage: "list.number", tint: .purple)
                }
            }
        }
        .onPencilDoubleTap { _ in
            guard preferredPencilDoubleTapAction != .ignore, vm.started else { return }
            showsPencilActions = true
        }
        .onPencilSqueeze { phase in
            guard preferredPencilSqueezeAction != .ignore, vm.started, case .ended = phase else { return }
            showsPencilActions = true
        }
        .confirmationDialog("Apple Pencil Actions", isPresented: $showsPencilActions, titleVisibility: .visible) {
            if !vm.showResult {
                if mode == .classic {
                    Button("Check Order", systemImage: "checkmark.circle", action: checkOrder)
                }
            } else {
                Button("Next Puzzle", systemImage: "arrow.right.circle", action: advanceToNextRound)
            }
            Button("Change Settings", systemImage: "slider.horizontal.3", action: endGame)
            Button("Cancel", role: .cancel) {}
        }
        .task(id: vm.started && !vm.showResult && isAppActive) {
            guard vm.started, !vm.showResult, isAppActive else { return }

            while !Task.isCancelled, vm.started, !vm.showResult, isAppActive {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }

                guard !Task.isCancelled, vm.started, !vm.showResult, isAppActive else { return }
                elapsedSeconds = roundClock.elapsedSeconds()
            }
        }
        .onAppActiveChange { active in
            isAppActive = active
            if active {
                roundClock.resume()
                quickRound?.resume()
            } else {
                roundClock.pause()
                quickRound?.pause()
            }
            elapsedSeconds = roundClock.elapsedSeconds()
            if !active {
                // Kept in case the app is closed from the background.
                vm.savePuzzle(elapsedSeconds: elapsedSeconds)
            }
        }
        .onAppear {
            // A review round goes straight to Missing Book questions about the missed books.
            if !reviewBooks.isEmpty, quickRound == nil {
                startQuickRound(.missingBook)
            }
        }
        .onDisappear {
            roundClock.pause()
            quickRound?.stop()
            // An unchecked puzzle comes back next time instead of being skipped.
            vm.savePuzzle(elapsedSeconds: roundClock.elapsedSeconds())
            vm.onDisappear()
        }
    }

    // MARK: - Setup

    private var setupScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Learn the order of the books of the Bible.")
                    .gameStartDescriptionStyle(title: "Book Order", systemImage: "list.number", tint: .purple)

                GameSplashLaunchLayout(
                    tint: .purple,
                    // A section too small for more than one level (like the Gospels) has
                    // nothing to choose, so the picker is hidden.
                    experienceLevel: (mode == .classic && vm.difficulty == .fullBible) || (mode.isPuzzle && vm.availableLevels.count < 2)
                        ? nil
                        : experienceLevel,
                    experienceDetails: experienceDetails,
                    startTitle: mode.isPuzzle && vm.hasSavedPuzzle ? "Resume" : "Start Game",
                    startSubtitle: mode.isPuzzle && vm.hasSavedPuzzle ? "Pick up where you left off." : "Begin your challenge.",
                    startAction: start
                ) {
                    GameLobbyPreview(kind: .bookOrder, bookOrderBooks: vm.source.previewBookNames)
                } configuration: {
                    BookOrderSetupControls(
                        mode: $vm.mode,
                        modes: BookOrderMode.available(isWide: isWide),
                        source: $vm.source,
                        difficulty: $vm.difficulty
                    )
                } facts: {
                    setupFacts
                }
            }
            .padding()
        }
        .accessibilityIdentifier("bookOrderSetupScrollView")
        .onAppear { vm.preparePuzzle(mode) }
        .onChange(of: vm.mode) { _, _ in vm.preparePuzzle(mode) }
    }

    private var experienceDetails: GameExperienceDetails {
        switch mode {
        case .tapInOrder, .classic:
            GameExperienceDetails(
                learn: "\(vm.bookCount(for: .easy)) books.",
                standard: "\(vm.bookCount(for: .normal)) books.",
                challenge: "\(vm.bookCount(for: .hard)) books."
            )
        case .beforeAfter:
            GameExperienceDetails(
                learn: "Books far apart.",
                standard: "Books a few apart.",
                challenge: "Books next to each other."
            )
        case .missingBook:
            GameExperienceDetails(
                learn: "Wrong choices from anywhere in the Bible.",
                standard: "Wrong choices from the same Testament.",
                challenge: "Wrong choices from the books nearby."
            )
        case .whichSection:
            GameExperienceDetails(
                learn: "Books from the whole Bible.",
                standard: "Books from the whole Bible.",
                challenge: "Books from the whole Bible."
            )
        }
    }

    @ViewBuilder
    private var setupFacts: some View {
        switch mode {
        case .tapInOrder, .classic:
            GameSplashFacts(
                first: (
                    "books.vertical",
                    mode == .classic && vm.difficulty == .fullBible && vm.source == .both
                        ? String(localized: "All 66 books")
                        : String(localized: "\(vm.roundBookCount) books"),
                    String(localized: "This session")
                ),
                second: ("stopwatch", vm.savedBestTime.map(Self.formatted) ?? "—", String(localized: "Best time")),
                third: ("flame.fill", "\(vm.persistentBestStreak)", String(localized: "Best streak"))
            )
        case .beforeAfter:
            GameSplashFacts(
                first: ("timer", "\(BookOrderQuickRound.beforeAfterSeconds) sec", String(localized: "Per round")),
                second: ("hand.tap.fill", String(localized: "Tap"), String(localized: "The first book")),
                third: ("trophy", "\(previewRound(.beforeAfter).bestBeforeAfterScore)", String(localized: "Best score"))
            )
        case .missingBook, .whichSection:
            GameSplashFacts(
                first: ("number", "\(BookOrderQuickRound.questionsPerRound) questions", String(localized: "This session")),
                second: ("square.grid.2x2", mode == .missingBook ? "4" : "8", String(localized: "Choices")),
                third: ("timer", String(localized: "No limit"), String(localized: "Per question"))
            )
        }
    }

    /// A round with the current settings, for reading its saved best score.
    private func previewRound(_ mode: BookOrderMode) -> BookOrderQuickRound {
        BookOrderQuickRound(mode: mode, difficulty: vm.difficulty, source: vm.source)
    }

    private func start() {
        if mode.isPuzzle {
            vm.preparePuzzle(mode)
            startGame()
        } else {
            startQuickRound(mode)
        }
    }

    private func startQuickRound(_ mode: BookOrderMode) {
        let round = BookOrderQuickRound(
            mode: mode,
            difficulty: vm.difficulty,
            source: vm.source,
            reviewBooks: reviewBooks
        )
        round.start()
        quickRound = round
    }

    private func quickRoundNote(_ round: BookOrderQuickRound) -> String? {
        guard round.mode == .beforeAfter else { return nil }
        return String(localized: "\(round.session.score) right in \(BookOrderQuickRound.beforeAfterSeconds) seconds · Best \(round.bestBeforeAfterScore)")
    }

    // MARK: - Tap in Order

    private var tapBoard: some View {
        ScrollView {
            VStack(spacing: 14) {
                GameScoreboardCard(
                    currentCorrect: vm.session.score,
                    currentAnswered: vm.session.answered,
                    currentStreak: vm.session.streak,
                    game: .bookorder,
                    style: isWide ? .dashboard : .compact
                )

                HStack(alignment: .firstTextBaseline) {
                    Text(tapPrompt)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    timerToggle
                }

                BookOrderPlacedRow(placed: vm.tapPlaced, total: vm.correctOrder.count)

                if let hint = vm.wrongTapHint, !vm.showResult {
                    Label(hint, systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(vm.wrongTapCount)
                        .transition(.opacity)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: isWide ? 170 : 140), spacing: 10)], spacing: 10) {
                    ForEach(vm.currentItems, id: \.self) { book in
                        BookOrderTile(
                            book: book,
                            isPlaced: vm.tapPlaced.contains(book),
                            wasMissed: vm.wrongTapBooks.contains(book)
                        ) {
                            vm.tap(book, elapsedSeconds: roundClock.elapsedSeconds())
                            if vm.showResult {
                                roundClock.pause()
                                elapsedSeconds = roundClock.elapsedSeconds()
                            }
                        }
                        .disabled(vm.showResult)
                    }
                }

                if vm.showResult {
                    resultSummary(compact: !isWide)
                    HStack(spacing: 12) {
                        Button("Change Settings", systemImage: "slider.horizontal.3", action: endGame)
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))

                        Button("Next Puzzle", systemImage: "arrow.right.circle.fill", action: advanceToNextRound)
                            .buttonStyle(GameProminentButtonStyle(tint: .purple))
                    }
                } else if debugAutoWinEnabled, !vm.correctOrder.isEmpty {
                    Button("WIN") {
                        for book in vm.correctOrder where !vm.tapPlaced.contains(book) {
                            vm.tap(book, elapsedSeconds: roundClock.elapsedSeconds())
                        }
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .accessibilityLabel("Win this round")
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding()
            .animation(.snappy, value: vm.tapPlaced)
        }
    }

    private var tapPrompt: String {
        let count = vm.correctOrder.count
        return switch vm.source {
        case .both: String(localized: "Tap these \(count) books in Bible order.")
        case .ot: String(localized: "Tap these \(count) Old Testament books in Bible order.")
        case .nt: String(localized: "Tap these \(count) New Testament books in Bible order.")
        default: String(localized: "Tap these \(count) \(String(localized: vm.source.title)) books in Bible order.")
        }
    }

    // MARK: - iPad Classic

    private func iPadGameBoard(availableHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            GameScoreboardCard(
                currentCorrect: vm.session.score,
                currentAnswered: vm.session.answered,
                currentStreak: vm.session.streak,
                game: .bookorder,
                style: .dashboard
            )
            .heroCardSurface()

            HStack(spacing: 12) {
                iPadBookListCard

                iPadTimerAndCanonCard
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
    }

    private var iPadBookListCard: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Arrange the Books", systemImage: "list.number")
                    .font(.headline.weight(.bold))
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            List {
                ForEach(Array(vm.currentItems.enumerated()), id: \.element) { index, item in
                    HStack(spacing: 10) {
                        Image(systemName: vm.showResult ? resultIcon(for: item) : "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(item)
                            .font(.body.weight(.medium))
                        Spacer()
                        if vm.showResult, let hint = vm.moveHint(for: item) {
                            Text(hint)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 46)
                    .glassEffect(answerGlass(for: item), in: .rect(cornerRadius: 12))
                    .hoverEffect(.lift)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .moveDisabled(vm.showResult)
                }
                .onMove(perform: vm.move)
            }
            .environment(\.editMode, .constant(EditMode.active))
            .scrollContentBackground(.hidden)

            if vm.showResult {
                resultSummary(compact: false)
            }

            actionButtons
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .heroCardSurface()
    }

    private var iPadTimerAndCanonCard: some View {
        VStack(spacing: 16) {
            if vm.showResult {
                HStack {
                    Label("Books of the Bible", systemImage: "books.vertical.fill")
                        .font(.headline.weight(.bold))

                    Spacer()

                    Label(formattedElapsedTime, systemImage: "stopwatch.fill")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(canonicalBooks.enumerated()), id: \.element) { index, book in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)

                                Text(book)
                                    .font(.body.weight(.medium))

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 46)
                            .glassEffect(canonGlass(for: book), in: .rect(cornerRadius: 12))
                            .id(book)
                        }
                    }
                    .padding(4)
                }
                // Brings the puzzle's books into view instead of always starting at Genesis.
                .onAppear {
                    if let first = vm.correctOrder.first {
                        proxy.scrollTo(first, anchor: .top)
                    }
                }
                }
            } else {
                Spacer()

                VStack(spacing: 14) {
                    if isTimerHidden {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Timer Hidden")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.tint)

                        Text(formattedElapsedTime)
                            .font(.largeTitle.weight(.bold))
                            .fontDesign(.rounded)
                            .monospacedDigit()

                        Text("Time Elapsed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if let best = vm.savedBestTime {
                        Label("Best \(Self.formatted(best))", systemImage: "trophy.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isTimerHidden ? "Timer hidden" : "Time elapsed")
                .accessibilityValue(isTimerHidden ? "" : formattedElapsedTime)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isTimerHidden.toggle()
                    }
                } label: {
                    Label(isTimerHidden ? "Show Timer" : "Hide Timer", systemImage: isTimerHidden ? "eye" : "eye.slash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .heroCardSurface()
    }

    // MARK: - Shared pieces

    private var prompt: String {
        let count = vm.correctOrder.count
        return switch vm.source {
        case .both: String(localized: "Put these \(count) books in Bible order.")
        case .ot: String(localized: "Put these \(count) Old Testament books in Bible order.")
        case .nt: String(localized: "Put these \(count) New Testament books in Bible order.")
        default: String(localized: "Put these \(count) \(String(localized: vm.source.title)) books in Bible order.")
        }
    }

    /// Elapsed time on iPhone, with a tap to hide it.
    private var timerToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isTimerHidden.toggle()
            }
        } label: {
            if isTimerHidden {
                Label("Show Timer", systemImage: "eye.slash")
                    .labelStyle(.iconOnly)
            } else {
                Label(formattedElapsedTime, systemImage: "stopwatch")
                    .monospacedDigit()
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .accessibilityLabel(isTimerHidden ? "Show timer" : "Time elapsed \(formattedElapsedTime). Hide timer")
    }

    /// The result card. On iPhone (`compact`) it leaves out the streak, best-time note and
    /// Books to Review, so the list of books stays visible.
    private func resultSummary(compact: Bool) -> some View {
        let total = vm.correctOrder.count
        return GamePuzzleResultCard(
            title: vm.wasCorrect
                ? String(localized: "Perfect Order")
                : (vm.puzzleMode == .tapInOrder
                    ? String(localized: "\(vm.booksInOrder) of \(total) right the first time")
                    : String(localized: "\(vm.booksInOrder) of \(total) in order")),
            subtitle: vm.wasCorrect
                ? String(localized: "All \(total) books are in the right order.")
                : (vm.puzzleMode == .tapInOrder
                    ? String(localized: "Books you tapped too early are added to your missed list.")
                    : String(localized: "Books marked in red are added to your missed list.")),
            systemImage: vm.wasCorrect ? "checkmark.seal.fill" : "arrow.up.arrow.down.circle.fill",
            tint: vm.wasCorrect ? .green : .red,
            facts: [
                ("stopwatch", GameTimeFormat.short(seconds: vm.lastTimeSeconds), String(localized: "Time")),
                ("checkmark.circle", "\(vm.booksInOrder)/\(total)", String(localized: "In order")),
                ("trophy", vm.bestTimeSeconds.map { GameTimeFormat.short(seconds: $0) } ?? "—", String(localized: "Best time"))
            ],
            bestTime: compact ? nil : vm.bestTimeComparison,
            streak: compact ? nil : GamePuzzleStreak(
                current: vm.session.savedCurrentStreak,
                best: vm.persistentBestStreak,
                isNewBest: vm.isNewBestStreak,
                caption: String(localized: "This visit: \(vm.session.score) of \(vm.session.answered) puzzles in order")
            )
        ) {
            if !compact, !vm.booksToReview.isEmpty {
                GamePuzzleResultSection(title: "Books to Review", systemImage: "books.vertical", tint: .red) {
                    ForEach(vm.booksToReview) { item in
                        Label(item.hint, systemImage: "arrow.turn.down.right")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if vm.showResult {
            HStack(spacing: 12) {
                Button("Change Settings", systemImage: "slider.horizontal.3", action: endGame)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))

                Button("Next Puzzle", systemImage: "arrow.right.circle.fill", action: advanceToNextRound)
                    .buttonStyle(GameProminentButtonStyle(tint: .purple))
            }
        } else {
            VStack(spacing: 10) {
                Button("Check", systemImage: "checkmark.circle.fill", action: checkOrder)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))

                // DEBUG: WIN button
                if debugAutoWinEnabled, !vm.correctOrder.isEmpty {
                    Button("WIN") {
                        vm.currentItems = vm.correctOrder
                        checkOrder()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .accessibilityLabel("Win this round")
                }
            }
        }
    }

    private var formattedElapsedTime: String {
        Self.formatted(elapsedSeconds)
    }

    nonisolated private static func formatted(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var canonicalBooks: [String] {
        BibleCanon.canonicalOrder()
    }

    private func rowBackground(for book: String) -> Color? {
        guard vm.showResult else { return nil }
        return vm.needsMoving(book) ? Color.red.opacity(0.15) : Color.green.opacity(0.15)
    }

    private func resultIcon(for book: String) -> String {
        vm.needsMoving(book) ? "xmark.circle.fill" : "checkmark.circle.fill"
    }

    private func answerGlass(for book: String) -> Glass {
        guard vm.showResult else { return .regular.interactive() }
        let tint: Color = vm.needsMoving(book) ? .red.opacity(0.3) : .green.opacity(0.3)
        return .regular.tint(tint)
    }

    private func canonGlass(for book: String) -> Glass {
        guard vm.correctOrder.contains(book) else { return .regular }
        return .regular.tint(.green.opacity(0.3))
    }

    private func startGame() {
        let resumedSeconds = vm.startGame()
        roundClock.start(alreadyElapsed: Double(resumedSeconds))
        if !isAppActive {
            roundClock.pause()
        }
        elapsedSeconds = roundClock.elapsedSeconds()
    }

    private func checkOrder() {
        roundClock.pause()
        elapsedSeconds = roundClock.elapsedSeconds()
        vm.checkOrder(elapsedSeconds: elapsedSeconds)
    }

    private func advanceToNextRound() {
        roundClock.start()
        if !isAppActive {
            roundClock.pause()
        }
        elapsedSeconds = roundClock.elapsedSeconds()
        vm.nextRound()
    }

    private func endGame() {
        roundClock.pause()
        elapsedSeconds = 0
        vm.endGame()
    }
}

#Preview {
    NavigationStack {
        BookOrderGameView()
    }
}
