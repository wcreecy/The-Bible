import SwiftUI
import SwiftData

/// A verse that can be asked or offered as a choice.
private struct MatchVerse: Hashable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String

    var reference: String { "\(bookName) \(chapterNumber):\(verseNumber)" }

    /// Lowercased letters only, so verses with the same words count as the same text.
    var normalizedText: String {
        verseText.lowercased().split { !$0.isLetter }.joined(separator: " ")
    }
}

private struct MatchQuestion {
    let verse: MatchVerse
    let options: [MatchVerse]
    let correctIndex: Int
    var selectedIndex: Int?
}

/// The well-known verses shared with the lock-screen widget (`LockScreenVerses.json`).
private enum WellKnownVerses {
    private struct Entry: Decodable {
        let book: String
        let chapter: Int
        let verse: Int
        let text: String
    }

    static func load() -> [MatchVerse] {
        guard let url = Bundle.main.url(forResource: "LockScreenVerses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.map {
            MatchVerse(bookName: $0.book, chapterNumber: $0.chapter, verseNumber: $0.verse, verseText: $0.text)
        }
    }
}

struct VerseMatchGameView: View {
    @Query private var favorites: [Favorite]

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy, normal, hard
        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .easy: "Easy"
            case .normal: "Normal"
            case .hard: "Hard"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .easy: "Wrong choices come from other parts of the Bible."
            case .normal: "Wrong choices come from anywhere in your categories."
            case .hard: "Every choice comes from the same book as the reference."
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: .easy
            case .normal: .normal
            case .hard: .hard
            }
        }
    }

    enum VersePool: String, CaseIterable, Identifiable {
        case wellKnown, favorites, any
        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .wellKnown: "Well-known"
            case .favorites: "Favorites"
            case .any: "Any verse"
            }
        }
    }

    typealias VerseSection = QuizView.VerseSection

    static let questionsPerGame = 10
    /// "Any verse" skips longer verses so four choices stay readable.
    static let maximumWords = 50

    private enum Phase {
        case setup
        case playing
        case results
    }

    @AppStorage("verseMatchDifficulty") private var difficulty: Difficulty = .normal
    @AppStorage("versematchPool") private var pool: VersePool = .wellKnown
    // Replaced by the category quick picks; read once to carry an old choice over.
    @AppStorage("versematchScope") private var legacyScope: String = "whole"
    @AppStorage("versematchSections") private var verseSectionsRaw: String = ""

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    @State private var phase: Phase = .setup
    @State private var isFilterReady = QuizVerseFilter.isReady
    @State private var wellKnownVerses: [MatchVerse] = []
    /// Fair verses (no lists, repeats, or very long verses) by book, for "Any verse" and fill-in choices.
    @State private var anyVersesByBook: [String: [MatchVerse]] = [:]

    @State private var history: [MatchQuestion] = []
    @State private var currentIndex: Int = -1
    @State private var questionBag: [MatchVerse] = []
    @State private var totalQuestions: Int = 0

    // Scoring
    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var sessionStreak: Int = 0
    @State private var sessionBestStreak: Int = 0
    @State private var currentBestStreak: Int = 0
    @State private var bestGameScore: Int = 0
    @State private var isNewBestGame: Bool = false

    @State private var referenceOnLeading = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Derived state

    private var selectedSections: Set<VerseSection> {
        Set(verseSectionsRaw.split(separator: ",").compactMap { VerseSection(rawValue: String($0)) })
    }

    /// An empty stored selection means every category.
    private var displayedSelectedSections: Set<VerseSection> {
        selectedSections.isEmpty ? Set(VerseSection.allCases) : selectedSections
    }

    private var poolBookNames: Set<String> {
        Set(displayedSelectedSections.flatMap(\.bookNames))
    }

    private var favoriteVerses: [MatchVerse] {
        favorites.map {
            MatchVerse(bookName: $0.bookName, chapterNumber: $0.chapterNumber,
                       verseNumber: $0.verseNumber, verseText: $0.verseText)
        }
    }

    /// The pool's own verses within the chosen categories, before any fill-in.
    private var preferredVerses: [MatchVerse] {
        let books = poolBookNames
        switch pool {
        case .wellKnown: return wellKnownVerses.filter { books.contains($0.bookName) }
        case .favorites: return uniqueByReference(favoriteVerses).filter { books.contains($0.bookName) }
        case .any: return []
        }
    }

    private var canStart: Bool {
        isFilterReady && (pool != .favorites || !preferredVerses.isEmpty)
    }

    private var poolDetail: String {
        let count = preferredVerses.count
        switch pool {
        case .wellKnown:
            return count >= Self.questionsPerGame
                ? String(localized: "\(count) popular verses in your categories.")
                : String(localized: "Only \(count) popular verses in your categories; other verses fill the rest.")
        case .favorites:
            return count == 0
                ? String(localized: "No favorite verses in your categories yet. Save some while reading.")
                : String(localized: "\(count) of your favorite verses in your categories.")
        case .any:
            return String(localized: "Any verse from your categories.")
        }
    }

    private var current: MatchQuestion? {
        history.indices.contains(currentIndex) ? history[currentIndex] : nil
    }

    private var isViewingPrevious: Bool { currentIndex < history.count - 1 }
    private var isAnswered: Bool { current?.selectedIndex != nil }
    private var isOnLastQuestion: Bool { !isViewingPrevious && history.count >= totalQuestions }

    // MARK: - Persistent streak (per difficulty)
    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "versematch", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String { "versematchBestGameScore_\(difficulty.rawValue)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch phase {
                case .setup:
                    setupContent
                case .playing:
                    gameContent
                case .results:
                    Spacer(minLength: 32)
                    VerseMatchResultsCard(
                        score: score,
                        total: totalQuestions,
                        bestStreak: sessionBestStreak,
                        bestGameScore: bestGameScore,
                        isNewBest: isNewBestGame,
                        onPlayAgain: startGame,
                        onChangeSettings: { phase = .setup }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if phase != .setup {
                    GameNavigationTitle(title: "Verse Match", systemImage: "text.quote", tint: .orange)
                }
            }
        }
        .onAppear {
            migrateLegacyScope()
            currentBestStreak = persistentStreak.best
            if wellKnownVerses.isEmpty {
                wellKnownVerses = WellKnownVerses.load()
            }
        }
        // Sort out list and repeated verses while the start screen is showing.
        .task {
            await QuizVerseFilter.prepare()
            isFilterReady = true
        }
        .onChange(of: difficulty) { _, _ in
            currentBestStreak = persistentStreak.best
        }
        .onDisappear {
            // Leaving after answering begins a new game on return.
            if phase != .setup && answered > 0 {
                phase = .setup
            }
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        Spacer(minLength: 32)
        Text("Choose the verse text that matches the reference.")
            .gameStartDescriptionStyle(title: "Verse Match", systemImage: "text.quote", tint: .orange)

        GameSplashLaunchLayout(tint: .orange, isStartEnabled: canStart, startAction: startGame) {
            GameLobbyPreview(kind: .verseMatch)
        } configuration: {
            VerseMatchSetupControls(
                difficulty: $difficulty,
                pool: $pool,
                poolDetail: poolDetail
            )

            VStack(alignment: .leading, spacing: 8) {
                QuizCategoryQuickPicks(selection: sectionSelection)

                GameStartMultiPickerCard(
                    title: "Biblical Categories",
                    selection: sectionSelection,
                    options: VerseSection.allCases
                ) { section in
                    Text(section.title)
                }
            }
            .frame(maxWidth: 620)
            .padding(.horizontal)

            if !isFilterReady {
                Label {
                    Text("Preparing verses…")
                } icon: {
                    ProgressView()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }
        } facts: {
            GameSplashFacts(
                first: ("number", "\(Self.questionsPerGame)", String(localized: "Questions")),
                second: ("text.quote", String(localized: pool.title), String(localized: "Verses")),
                third: ("square.stack.3d.up", "4", String(localized: "Choices"))
            )
        }
        Spacer(minLength: 32)
    }

    private var sectionSelection: Binding<Set<VerseSection>> {
        Binding(
            get: { displayedSelectedSections },
            set: storeSelectedSections
        )
    }

    private func storeSelectedSections(_ sections: Set<VerseSection>) {
        guard !sections.isEmpty else { return }
        if sections == Set(VerseSection.allCases) {
            verseSectionsRaw = ""
        } else {
            verseSectionsRaw = VerseSection.allCases
                .filter { sections.contains($0) }
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    /// The Testament picker was folded into the categories; apply an old choice once.
    private func migrateLegacyScope() {
        guard legacyScope == "old" || legacyScope == "new" else { return }
        let testamentSections = Set(VerseSection.allCases.filter { $0.isOldTestament == (legacyScope == "old") })
        let kept = selectedSections.intersection(testamentSections)
        storeSelectedSections(kept.isEmpty ? testamentSections : kept)
        legacyScope = "whole"
    }

    // MARK: - Gameplay

    @ViewBuilder
    private var gameContent: some View {
        if let current {
            GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: sessionStreak,
                game: .versematch,
                style: horizontalSizeClass == .regular ? .dashboard : .compact
            )

            VerseMatchBoard(
                reference: current.verse.reference,
                progressText: String(localized: "Question \(currentIndex + 1) of \(totalQuestions)"),
                options: current.options,
                selectedIndex: current.selectedIndex,
                correctIndex: current.correctIndex,
                isLocked: isAnswered || isViewingPrevious,
                usesSideBySideLayout: horizontalSizeClass == .regular,
                referenceOnLeading: $referenceOnLeading,
                onSelect: select
            )

            if isAnswered {
                VerseMatchNavigationButtons(
                    canGoPrevious: currentIndex > 0,
                    isLastQuestion: isOnLastQuestion,
                    onPrevious: { currentIndex -= 1 },
                    onNext: showNext
                )
            }

            // DEBUG: WIN button
            if debugAutoWinEnabled, !isAnswered, !isViewingPrevious {
                Button("WIN") {
                    select(current.correctIndex)
                }
                .buttonStyle(ModernPillButtonStyle(tint: .red))
                .controlSize(.large)
                .padding(.top, 6)
                .accessibilityLabel("Win this round")
            }
        }
    }

    // MARK: - Game flow

    private func startGame() {
        guard canStart else { return }
        anyVersesByBook = buildAnyVerses()
        questionBag = buildQuestionBag()
        guard !questionBag.isEmpty else { return }
        totalQuestions = min(Self.questionsPerGame, questionBag.count)
        history = []
        currentIndex = -1
        score = 0
        answered = 0
        sessionStreak = 0
        sessionBestStreak = 0
        isNewBestGame = false
        currentBestStreak = persistentStreak.best
        phase = .playing
        appendNextQuestion()
    }

    private func showNext() {
        if isViewingPrevious {
            currentIndex += 1
        } else if history.count >= totalQuestions {
            showResults()
        } else {
            appendNextQuestion()
        }
    }

    private func appendNextQuestion() {
        while let verse = questionBag.popLast() {
            let wrong = wrongChoices(for: verse)
            guard wrong.count == 3 else { continue }
            let options = (wrong + [verse]).shuffled()
            guard let correctIndex = options.firstIndex(of: verse) else { continue }
            history.append(MatchQuestion(verse: verse, options: options, correctIndex: correctIndex))
            currentIndex = history.count - 1
            return
        }
        // Ran out of usable verses early; end with what was played.
        totalQuestions = history.count
        showResults()
    }

    private func showResults() {
        let previousBest = UserDefaults.standard.integer(forKey: bestGameScoreKey)
        isNewBestGame = score > previousBest
        bestGameScore = max(previousBest, score)
        if isNewBestGame {
            UserDefaults.standard.set(score, forKey: bestGameScoreKey)
        }
        phase = .results
    }

    private func select(_ index: Int) {
        guard !isViewingPrevious, let current, current.selectedIndex == nil else { return }
        history[currentIndex].selectedIndex = index
        answered += 1

        let isCorrect = index == current.correctIndex
        if isCorrect {
            score += 1
            sessionStreak += 1
            sessionBestStreak = max(sessionBestStreak, sessionStreak)
            // Persistent streak: extend on correct
            let streak = persistentStreak.recordWin()
            currentBestStreak = max(currentBestStreak, streak.best)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            // Persistent streak: reset on incorrect
            sessionStreak = 0
            persistentStreak.reset()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        GameStats.shared.recordRound(
            game: .versematch,
            difficulty: difficulty.statsDifficulty,
            correct: isCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )
        GameStats.shared.recordVerseMatchPerBook(bookName: current.verse.bookName, answered: 1, correct: isCorrect ? 1 : 0)
    }

    // MARK: - Verses

    private func uniqueByReference(_ verses: [MatchVerse]) -> [MatchVerse] {
        var seen: Set<String> = []
        return verses.filter { seen.insert($0.reference).inserted }
    }

    /// Every fair verse, grouped by book: no lists, cross-book repeats, or very long verses.
    private func buildAnyVerses() -> [String: [MatchVerse]] {
        var result: [String: [MatchVerse]] = [:]
        for book in BibleData.books {
            result[book.name] = book.chapters.flatMap { chapter in
                chapter.verses.compactMap { verse -> MatchVerse? in
                    guard QuizVerseFilter.isQuizzable(book: book.name, chapter: chapter.number, verse: verse.number, difficulty: "normal"),
                          verse.text.split(separator: " ").count <= Self.maximumWords else { return nil }
                    return MatchVerse(bookName: book.name, chapterNumber: chapter.number,
                                      verseNumber: verse.number, verseText: verse.text)
                }
            }
        }
        return result
    }

    /// Verses to ask, drawn evenly across every verse rather than book by book.
    private func buildQuestionBag() -> [MatchVerse] {
        let books = poolBookNames
        let anyVerses = anyVersesByBook.filter { books.contains($0.key) }.values.flatMap { $0 }
        switch pool {
        case .any:
            return anyVerses.shuffled()
        case .wellKnown, .favorites:
            let preferred = preferredVerses.shuffled()
            guard preferred.count < Self.questionsPerGame, pool == .wellKnown else { return preferred }
            // Few popular verses in these categories: top up with other verses, asked last.
            let used = Set(preferred.map(\.reference))
            let fill = anyVerses.filter { !used.contains($0.reference) }.shuffled()
                .prefix(Self.questionsPerGame - preferred.count)
            return Array(fill) + preferred
        }
    }

    /// Picks three wrong verses with different text, following the Quiz's rules for books:
    /// Easy uses other sections, Normal anywhere in your categories, Hard the same book.
    /// Verses from the chosen pool are tried before other verses.
    private func wrongChoices(for target: MatchVerse) -> [MatchVerse] {
        let canon = BibleCanon.fallbackCanon
        let categories = poolBookNames
        let section = VerseSection.containing(target.bookName)
        let isOld = section?.isOldTestament ?? true
        let sameTestament = canon.filter { VerseSection.containing($0)?.isOldTestament == isOld }

        let bookTiers: [[String]]
        switch difficulty {
        case .easy:
            let otherSections = canon.filter { VerseSection.containing($0) != section }
            bookTiers = [otherSections.filter(categories.contains), otherSections]
        case .normal:
            bookTiers = [canon.filter(categories.contains), sameTestament, canon]
        case .hard:
            // Fall back to the same section only if the book lacks three usable verses.
            let family = Set((section?.hardFamily ?? []).flatMap(\.bookNames))
            bookTiers = [[target.bookName], canon.filter(family.contains)]
        }
        let distinctBooks = difficulty != .hard
        let preferred = pool == .any ? [] : preferredVerses

        var picks: [MatchVerse] = []
        var usedTexts: Set<String> = [target.normalizedText]
        var usedBooks: Set<String> = distinctBooks ? [target.bookName] : []

        func add(_ verse: MatchVerse) {
            guard picks.count < 3, verse.reference != target.reference,
                  !usedBooks.contains(verse.bookName),
                  !usedTexts.contains(verse.normalizedText) else { return }
            usedTexts.insert(verse.normalizedText)
            if distinctBooks { usedBooks.insert(verse.bookName) }
            picks.append(verse)
        }

        for tier in bookTiers where picks.count < 3 {
            let tierBooks = Set(tier)
            for verse in preferred.shuffled() where tierBooks.contains(verse.bookName) {
                add(verse)
            }
            for book in tier.shuffled() where picks.count < 3 {
                let verses = anyVersesByBook[book] ?? []
                for verse in verses.shuffled().prefix(distinctBooks ? 3 : 30) {
                    add(verse)
                }
            }
        }
        return picks
    }
}

// MARK: - Setup views

private struct VerseMatchSetupControls: View {
    @Binding var difficulty: VerseMatchGameView.Difficulty
    @Binding var pool: VerseMatchGameView.VersePool
    let poolDetail: String

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verses")
                    .font(.headline)

                Picker("Verses", selection: $pool) {
                    ForEach(VerseMatchGameView.VersePool.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(poolDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.headline)

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(VerseMatchGameView.Difficulty.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(difficulty.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal)
    }
}

// MARK: - Gameplay views

private struct VerseMatchBoard: View {
    let reference: String
    let progressText: String
    let options: [MatchVerse]
    let selectedIndex: Int?
    let correctIndex: Int
    let isLocked: Bool
    let usesSideBySideLayout: Bool
    @Binding var referenceOnLeading: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        if usesSideBySideLayout {
            HStack(alignment: .top, spacing: 20) {
                if referenceOnLeading {
                    referenceCard
                    answersCard
                } else {
                    answersCard
                    referenceCard
                }
            }
            .animation(.easeInOut(duration: 0.2), value: referenceOnLeading)
        } else {
            VStack(spacing: 16) {
                referenceCard
                answersCard
            }
        }
    }

    private var referenceCard: some View {
        VerseMatchReferenceCard(
            reference: reference,
            progressText: progressText,
            showsSwapButton: usesSideBySideLayout,
            onSwap: { referenceOnLeading.toggle() }
        )
        .frame(maxWidth: .infinity)
    }

    private var answersCard: some View {
        VerseMatchAnswersCard(
            options: options,
            selectedIndex: selectedIndex,
            correctIndex: correctIndex,
            isLocked: isLocked,
            onSelect: onSelect
        )
        .frame(maxWidth: .infinity)
    }
}

private struct VerseMatchReferenceCard: View {
    let reference: String
    let progressText: String
    let showsSwapButton: Bool
    let onSwap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Text(progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer(minLength: 12)

                Text(reference)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 12)
            }

            if showsSwapButton {
                Button(action: onSwap) {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Swap card sides")
                .accessibilityHint("Moves the reference and answers cards to opposite sides.")
            }
        }
        .frame(maxWidth: .infinity, minHeight: showsSwapButton ? 280 : 160)
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }
}

private struct VerseMatchAnswersCard: View {
    let options: [MatchVerse]
    let selectedIndex: Int?
    let correctIndex: Int
    let isLocked: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Potential Answers", systemImage: "text.page")
                .font(.headline)

            Text("Which verse matches this reference?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        onSelect(index)
                    } label: {
                        Text("“\(option.verseText)”")
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                    .accessibilityValue(accessibilityState(for: index))

                    if selectedIndex != nil {
                        HStack(spacing: 8) {
                            Text(option.reference)
                                .font(.caption.weight(index == correctIndex ? .bold : .regular))
                                .foregroundStyle(index == correctIndex ? Color.green : Color.secondary)

                            Spacer()

                            VerseActionMenu(
                                verse: VerseActionReference(
                                    bookName: option.bookName,
                                    chapterNumber: option.chapterNumber,
                                    verseNumber: option.verseNumber,
                                    verseText: option.verseText
                                )
                            )
                        }
                    }
                }
                .padding()
                .background(backgroundColor(for: index))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor(for: index), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let selectedIndex {
                Label(
                    selectedIndex == correctIndex ? "Correct!" : "Not quite",
                    systemImage: selectedIndex == correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(selectedIndex == correctIndex ? .green : .red)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }

    private func accessibilityState(for index: Int) -> String {
        guard let selectedIndex else { return "" }
        if index == correctIndex { return String(localized: "Correct answer") }
        if index == selectedIndex { return String(localized: "Your answer, incorrect") }
        return ""
    }

    private func backgroundColor(for index: Int) -> Color {
        guard let selectedIndex else {
            return Color(.secondarySystemBackground)
        }
        if index == correctIndex {
            return Color.green.opacity(0.18)
        }
        if index == selectedIndex, selectedIndex != correctIndex {
            return Color.red.opacity(0.18)
        }
        return Color(.secondarySystemBackground)
    }

    private func borderColor(for index: Int) -> Color {
        guard let selectedIndex else {
            return Color.black.opacity(0.12)
        }
        if index == correctIndex {
            return Color.green.opacity(0.6)
        }
        if index == selectedIndex, selectedIndex != correctIndex {
            return Color.red.opacity(0.6)
        }
        return Color.black.opacity(0.12)
    }
}

private struct VerseMatchNavigationButtons: View {
    let canGoPrevious: Bool
    let isLastQuestion: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Previous", systemImage: "arrow.left", action: onPrevious)
                .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                .disabled(!canGoPrevious)

            if isLastQuestion {
                Button("See Results", systemImage: "flag.checkered", action: onNext)
                    .buttonStyle(GameProminentButtonStyle(tint: .orange))
            } else {
                Button("Next", systemImage: "arrow.right", action: onNext)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
            }
        }
    }
}

private struct VerseMatchResultsCard: View {
    let score: Int
    let total: Int
    let bestStreak: Int
    let bestGameScore: Int
    let isNewBest: Bool
    let onPlayAgain: () -> Void
    let onChangeSettings: () -> Void

    private var accuracy: Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isNewBest ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(isNewBest ? Color.yellow : Color.orange)

            VStack(spacing: 6) {
                Text(isNewBest ? "New Best Game!" : "Game Over")
                    .font(.title.weight(.bold))

                Text("\(score) of \(total) correct")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GameSplashFacts(
                first: ("percent", "\(accuracy)%", String(localized: "Accuracy")),
                second: ("flame.fill", "\(bestStreak)", String(localized: "Best streak")),
                third: ("trophy", "\(bestGameScore)/\(total)", String(localized: "Best game"))
            )

            VStack(spacing: 10) {
                Button("Play Again", systemImage: "arrow.clockwise", action: onPlayAgain)
                    .buttonStyle(GameProminentButtonStyle(tint: .orange))

                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .heroCardSurface()
    }
}
