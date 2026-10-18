import SwiftUI
import UIKit

struct HangmanGameView: View {
    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    enum Theme: String, CaseIterable, Identifiable {
        // Raw values are stored in settings and per-category stats.
        case all = "All"
        case people = "People"
        case places = "Places"
        case books = "Books"
        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .all: "Mixed"
            case .people: "People"
            case .places: "Places"
            case .books: "Books"
            }
        }

        var systemImage: String {
            switch self {
            case .people: "person.fill"
            case .places: "mappin.and.ellipse"
            case .books: "book.fill"
            case .all: "square.grid.2x2.fill"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .all: "People, places, and books"
            case .people: "Bible people"
            case .places: "Bible places"
            case .books: "Books of the Bible"
            }
        }
    }

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "Easy"
        case normal = "Normal"   // was Medium
        case hard = "Hard"
        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .easy: "Easy"
            case .normal: "Normal"
            case .hard: "Hard"
            }
        }

        var maxWrong: Int {
            switch self {
            case .easy: 8
            case .normal: 6
            case .hard: 5
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .easy: "Well-known names, 8 mistakes, and a clue for every word."
            case .normal: "Adds less familiar names and allows 6 mistakes. A clue costs one mistake."
            case .hard: "Every name in the game, 5 mistakes, and no clues."
            }
        }

        var clueSummary: String {
            switch self {
            case .easy: String(localized: "Shown")
            case .normal: String(localized: "−1 mistake")
            case .hard: String(localized: "None")
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: .easy
            case .normal: .medium
            case .hard: .hard
            }
        }

        /// Easy uses easy entries, Normal adds medium ones, and Hard uses everything.
        func includes(_ entryDifficulty: String) -> Bool {
            switch entryDifficulty.lowercased() {
            case "easy": true
            case "medium", "normal": self != .easy
            default: self == .hard
            }
        }
    }

    static let wordsPerGame = 10

    private enum Phase {
        case setup
        case playing
        case results
    }

    /// One puzzle: the name to guess plus what's revealed about it.
    private struct HangmanWord {
        let answer: String
        let category: Theme
        let clue: String
        /// The description in parentheses in the data, e.g. "son of Jacob". Not part of the puzzle.
        let qualifier: String?
        let reference: String?
    }

    @AppStorage("hangmanTheme") private var theme: Theme = .all
    @AppStorage("hangmanDifficulty") private var difficulty: Difficulty = .normal

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: {
                switch difficulty {
                case .easy: .learn
                case .normal: .standard
                case .hard: .challenge
                }
            },
            set: { level in
                difficulty = switch level {
                case .learn: .easy
                case .standard: .normal
                case .challenge: .hard
                }
            }
        )
    }

    @State private var phase: Phase = .setup
    @State private var loadedPeople: [BibleCharacter] = []
    @State private var loadedPlaces: [BibleLocationChallenge] = []

    // Game
    @State private var deck: [HangmanWord] = []
    @State private var current: HangmanWord?
    @State private var wordNumber: Int = 0
    @State private var totalWords: Int = 0

    // Round
    @State private var guessedLetters: Set<Character> = []
    @State private var wrongGuesses: Int = 0
    @State private var clueRevealed: Bool = false
    @State private var roundOver: Bool = false
    @State private var didWin: Bool = false

    // Scoring
    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var sessionStreak: Int = 0
    @State private var sessionBestStreak: Int = 0
    @State private var currentBestStreak: Int = 0
    @State private var bestGameScore: Int = 0
    @State private var isNewBestGame: Bool = false

    // Smart link style preview state (mirror Wordle)
    @State private var showRefSheet: Bool = false
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil

    // Keyboard layout toggle: false = QWERTY, true = A-Z
    @State private var useAlphabeticalLayout: Bool = false
    @State private var showsOnScreenKeyboard: Bool = true
    @State private var showsHangmanCardFirst: Bool = false

    private var maxWrong: Int { difficulty.maxWrong }

    private var answerLetters: Set<Character> {
        Set((current?.answer ?? "").uppercased().filter(\.isLetter))
    }

    private var correctLetters: Set<Character> { guessedLetters.intersection(answerLetters) }
    private var wrongLetters: Set<Character> { guessedLetters.subtracting(answerLetters) }

    private var isLastWord: Bool { deck.isEmpty }

    private var canRevealClue: Bool {
        difficulty == .normal && !clueRevealed && !roundOver && wrongGuesses < maxWrong - 1
    }

    private var showsClue: Bool {
        difficulty == .easy || clueRevealed || roundOver
    }

    // MARK: - Persistent streak (per difficulty)
    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "hangman", variant: difficulty.rawValue.lowercased())
    }

    private var bestGameScoreKey: String { "hangmanBestGameScore_\(difficulty.rawValue.lowercased())" }

    var body: some View {
        GeometryReader { geometry in
            let usesWideLayout = phase == .playing && geometry.size.width >= 900

            ScrollView {
                VStack(spacing: 12) {
                    switch phase {
                    case .setup:
                        startSection
                    case .playing:
                        #if canImport(UIKit)
                        KeyCaptureRepresentable(
                            onKey: { ch in
                                if !roundOver {
                                    guess(ch)
                                }
                            },
                            onBackspace: {},
                            onEnter: {
                                if roundOver {
                                    nextWord()
                                }
                            }
                        )
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                        #endif

                        inGameSection(
                            usesWideLayout: usesWideLayout,
                            availableHeight: geometry.size.height - 24
                        )

                        if debugAutoWinEnabled, !roundOver {
                            Button("WIN") {
                                guessedLetters.formUnion(answerLetters)
                                endRound(win: true)
                            }
                            .buttonStyle(ModernPillButtonStyle(tint: .red))
                            .controlSize(.large)
                            .padding(.top, 6)
                            .accessibilityLabel("Win this round")
                        }
                    case .results:
                        Spacer(minLength: 32)
                        HangmanResultsCard(
                            score: score,
                            total: totalWords,
                            bestStreak: sessionBestStreak,
                            bestGameScore: bestGameScore,
                            isNewBest: isNewBestGame,
                            onPlayAgain: startGame,
                            onChangeSettings: { phase = .setup }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if phase != .setup {
                    GameNavigationTitle(title: "Hangman", systemImage: "text.word.spacing", tint: .teal)
                }
            }
        }
        .task {
            if loadedPeople.isEmpty { loadedPeople = await GameDataLoaders.loadCharactersAsync() }
            if loadedPlaces.isEmpty { loadedPlaces = await GameDataLoaders.loadLocationChallengesAsync() }
        }
        .onAppear {
            currentBestStreak = persistentStreak.best
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
        .sheet(isPresented: $showRefSheet, onDismiss: {
            selectedRef = nil
            loadedPreview = nil
        }) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    if let preview = loadedPreview {
                        ScripturePreviewCard(
                            content: preview,
                            refContext: selectedRef,
                            onCopy: {
                                let verseLines = preview.verses.map { $0.text }.joined(separator: " ")
                                UIPasteboard.general.string = "\(preview.title) — \(verseLines)"
                            },
                            onClose: { showRefSheet = false }
                        )
                    } else {
                        ContentUnavailableView("No reference available", systemImage: "book")
                    }
                }
                .padding()
                .navigationTitle("Reference")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showRefSheet = false }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .task(id: selectedRef) {
                guard let sr = selectedRef else { return }
                loadedPreview = BibleReferenceLinker.loadVerses(for: sr)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var startSection: some View {
        Spacer(minLength: 24)
        Text("Guess the person, place or book from the Bible")
            .gameStartDescriptionStyle(title: "Hangman", systemImage: "text.word.spacing", tint: .teal)

        GameSplashLaunchLayout(
            tint: .teal,
            experienceLevel: experienceLevel,
            isStartEnabled: !loadedPeople.isEmpty && !loadedPlaces.isEmpty,
            startAction: startGame
        ) {
            GameLobbyPreview(kind: .hangman)
        } configuration: {
            HangmanSetupControls(theme: $theme)
        } facts: {
            GameSplashFacts(
                first: ("number", "\(Self.wordsPerGame)", String(localized: "Words")),
                second: ("xmark.octagon", "\(difficulty.maxWrong)", String(localized: "Mistakes allowed")),
                third: ("lightbulb", difficulty.clueSummary, String(localized: "Clue"))
            )
        }
        Spacer(minLength: 24)
    }

    private func inGameSection(usesWideLayout: Bool, availableHeight: CGFloat) -> some View {
        HangmanResponsiveLayout(
            usesWideLayout: usesWideLayout,
            availableHeight: availableHeight,
            showsKeyboardCard: showsOnScreenKeyboard,
            showsHangmanCardFirst: showsHangmanCardFirst,
            toggleKeyboardCard: { showsOnScreenKeyboard.toggle() },
            swapCards: { showsHangmanCardFirst.toggle() }
        ) {
            roundHeader
                .padding(.horizontal, 4)
        } word: {
            VStack(spacing: 12) {
                Text(spacedDisplayWord)
                    .font(.title.weight(.semibold).monospaced())
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Word to guess")
                    .accessibilityValue(spokenDisplayWord)

                Text("Mistakes: \(wrongGuesses)/\(maxWrong)")
                    .font(.subheadline)
                    .foregroundStyle(wrongGuesses >= maxWrong - 1 ? .red : .secondary)

                if roundOver, let current {
                    HangmanRevealCard(
                        didWin: didWin,
                        answer: current.answer,
                        qualifier: current.qualifier,
                        clue: current.clue,
                        reference: current.reference,
                        onShowReference: presentReferencePreview
                    )
                } else {
                    clueRow
                }
            }
        } drawing: {
            VStack(spacing: 18) {
                HangmanDrawing(
                    progress: Double(wrongGuesses) / Double(max(1, maxWrong)),
                    maximumCharacterHeight: usesWideLayout && !showsOnScreenKeyboard ? 520 : 310
                )
                .frame(
                    height: usesWideLayout
                        ? (showsOnScreenKeyboard
                            ? 280
                            : min(440, max(340, availableHeight * 0.48)))
                        : drawingHeight
                )
                .padding(.horizontal, 12)

                if usesWideLayout && !showsOnScreenKeyboard {
                    playedLettersTray
                }
            }
        } scoreboard: {
            GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: sessionStreak,
                game: .hangman,
                style: usesWideLayout ? .dashboard : .compact
            )
        } keyboard: {
            if roundOver {
                Group {
                    if isLastWord {
                        Button("See Results", systemImage: "flag.checkered", action: nextWord)
                            .buttonStyle(GameProminentButtonStyle(tint: .teal))
                    } else {
                        Button("Next Word", systemImage: "arrow.right", action: nextWord)
                            .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 8)
            } else {
                keyboardView(keyHeight: usesWideLayout ? 60 : 42)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var clueRow: some View {
        if let current, !current.clue.isEmpty {
            if showsClue {
                Label(current.clue, systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if difficulty == .normal {
                Button("Show clue (costs 1 mistake)", systemImage: "lightbulb", action: revealClue)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                    .disabled(!canRevealClue)
            }
        }
    }

    private var playedLettersTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Played Letters")
                .font(.headline)

            if guessedLetters.isEmpty {
                Text("No letters played yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 36), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(guessedLetters.sorted(), id: \.self) { letter in
                        Text(String(letter))
                            .font(.headline.monospaced())
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                correctLetters.contains(letter) ? Color.green : Color.red,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .accessibilityLabel(
                                correctLetters.contains(letter)
                                    ? "\(String(letter)), correct"
                                    : "\(String(letter)), incorrect"
                            )
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var roundHeader: some View {
        let category = current?.category ?? .all
        HStack(spacing: 8) {
            Label {
                Text(category.title)
                    .textCase(.uppercase)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: category.systemImage)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.18), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.45), lineWidth: 1)
            )
            .foregroundStyle(.orange)

            Spacer(minLength: 6)

            Text("Word \(wordNumber) of \(totalWords)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var drawingHeight: CGFloat {
        // Smaller to emphasize tighter proportions
        UIDevice.current.userInterfaceIdiom == .pad ? 130 : 100
    }

    // MARK: - Words

    /// Removes a trailing description in parentheses: "Jordan (river)" → ("Jordan", "river").
    private static func split(_ name: String) -> (answer: String, qualifier: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "("), trimmed.hasSuffix(")") else { return (trimmed, nil) }
        let answer = trimmed[..<open].trimmingCharacters(in: .whitespaces)
        let qualifier = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        return (answer.isEmpty ? trimmed : answer, qualifier.isEmpty ? nil : qualifier)
    }

    private func peopleWords() -> [HangmanWord] {
        loadedPeople
            .filter { difficulty.includes($0.difficulty) }
            .map { entry in
                let parts = Self.split(entry.name)
                return HangmanWord(answer: parts.answer, category: .people, clue: entry.shortDescription,
                                   qualifier: parts.qualifier, reference: nil)
            }
    }

    private func placeWords() -> [HangmanWord] {
        loadedPlaces
            .filter { difficulty.includes($0.difficulty) }
            .map { entry in
                let parts = Self.split(entry.locationName)
                return HangmanWord(answer: parts.answer, category: .places, clue: entry.shortDescription,
                                   qualifier: parts.qualifier,
                                   reference: entry.scriptureMentioned.isEmpty ? nil : entry.scriptureMentioned)
            }
    }

    private func bookWords() -> [HangmanWord] {
        BibleCanon.canonicalOrder().map { name in
            let section = QuizView.VerseSection.containing(name)
            let testament = section?.isOldTestament == false
                ? String(localized: "New Testament")
                : String(localized: "Old Testament")
            let clue = section.map { "\(testament) · \(String(localized: $0.title))" } ?? testament
            return HangmanWord(answer: name, category: .books, clue: clue, qualifier: nil, reference: nil)
        }
    }

    /// Draws the game's words without repeats. Mixed picks a category for each word.
    private func makeDeck() -> [HangmanWord] {
        var pools: [Theme: [HangmanWord]] = [:]
        let themes: [Theme] = theme == .all ? [.people, .places, .books] : [theme]
        for item in themes {
            switch item {
            case .people: pools[item] = peopleWords().shuffled()
            case .places: pools[item] = placeWords().shuffled()
            case .books: pools[item] = bookWords().shuffled()
            case .all: break
            }
        }

        var words: [HangmanWord] = []
        var usedAnswers: Set<String> = []
        while words.count < Self.wordsPerGame {
            let available = themes.filter { !(pools[$0]?.isEmpty ?? true) }
            guard let pick = available.randomElement(), let word = pools[pick]?.popLast() else { break }
            // Same-named people or places ("Joseph", "Bethlehem") would look like repeats.
            guard usedAnswers.insert(word.answer.uppercased()).inserted else { continue }
            words.append(word)
        }
        return words
    }

    // MARK: - Game flow

    private func startGame() {
        deck = makeDeck()
        guard !deck.isEmpty else { return }
        totalWords = deck.count
        wordNumber = 0
        score = 0
        answered = 0
        sessionStreak = 0
        sessionBestStreak = 0
        isNewBestGame = false
        currentBestStreak = persistentStreak.best
        phase = .playing
        nextWord()
    }

    private func nextWord() {
        guard let word = deck.popLast() else {
            showResults()
            return
        }
        current = word
        wordNumber += 1
        guessedLetters = []
        wrongGuesses = 0
        clueRevealed = false
        roundOver = false
        didWin = false
    }

    private func showResults() {
        let previousBest = UserDefaults.standard.integer(forKey: bestGameScoreKey)
        isNewBestGame = score > previousBest
        bestGameScore = max(previousBest, score)
        if isNewBestGame {
            UserDefaults.standard.set(score, forKey: bestGameScoreKey)
        }
        current = nil
        phase = .results
    }

    private func revealClue() {
        guard canRevealClue else { return }
        clueRevealed = true
        wrongGuesses += 1
    }

    /// Letters found so far, with blanks for the rest; spaces and punctuation always show.
    private var displayWord: String {
        String((current?.answer ?? "").map { ch in
            guard ch.isLetter else { return ch }
            let upper = Character(String(ch).uppercased())
            return roundOver || guessedLetters.contains(upper) ? upper : "_"
        })
    }

    private var spacedDisplayWord: String {
        displayWord.map { String($0) }.joined(separator: " ")
    }

    /// What VoiceOver reads for the word, e.g. "J, blank, S, blank".
    private var spokenDisplayWord: String {
        let blank = String(localized: "blank")
        return displayWord.map { $0 == "_" ? blank : String($0) }.joined(separator: ", ")
    }

    private func guess(_ ch: Character) {
        guard !roundOver else { return }
        let upper = Character(String(ch).uppercased())
        guard upper.isLetter, !guessedLetters.contains(upper) else { return }
        guessedLetters.insert(upper)

        if answerLetters.contains(upper) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if answerLetters.isSubset(of: guessedLetters) {
                endRound(win: true)
            }
        } else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            wrongGuesses += 1
            if wrongGuesses >= maxWrong {
                endRound(win: false)
            }
        }
    }

    private func endRound(win: Bool) {
        guard !roundOver, let current else { return }
        roundOver = true
        didWin = win
        showsOnScreenKeyboard = true
        answered += 1

        if win {
            score += 1
            sessionStreak += 1
            sessionBestStreak = max(sessionBestStreak, sessionStreak)
            // Persistent streak: extend on correct
            let streak = persistentStreak.recordWin()
            currentBestStreak = max(currentBestStreak, streak.best)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            // Persistent streak: reset on loss
            sessionStreak = 0
            persistentStreak.reset()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        GameStats.shared.recordRound(
            game: .hangman,
            difficulty: difficulty.statsDifficulty,
            correct: win ? 1 : 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )
        // Per-category (People/Places/Books) accuracy
        GameStats.shared.recordHangmanCategory(
            category: current.category.rawValue,
            answered: 1,
            correct: win ? 1 : 0
        )
    }

    // MARK: - References

    private func presentReferencePreview(from refString: String) {
        selectedRef = parseScriptureRef(from: refString)
        loadedPreview = nil
        showRefSheet = true
    }

    private func parseScriptureRef(from ref: String) -> ScriptureRef? {
        let attributed = BibleReferenceLinker.linkify(ref)
        for run in attributed.runs {
            if let url = run.attributes.link, let parsed = BibleReferenceLinker.parse(url: url) {
                return parsed
            }
        }

        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split { $0.isWhitespace }
        guard let lastPart = parts.last else { return nil }
        var last = String(lastPart)
        last = last.replacingOccurrences(of: "\u{2013}", with: "-")
        last = last.replacingOccurrences(of: "\u{2014}", with: "-")
        last = last.trimmingCharacters(in: CharacterSet(charactersIn: ",;.)]”’\""))
        guard let colonIndex = last.firstIndex(of: ":") else { return nil }
        let chapterSlice = last[..<colonIndex]
        let verseSlice = last[last.index(after: colonIndex)...]
        let chapterDigits = chapterSlice.prefix { $0.isNumber }
        let verseDigits = verseSlice.prefix { $0.isNumber }
        guard let chapterNum = Int(chapterDigits), let verseNum = Int(verseDigits) else { return nil }
        let bookRaw = parts.dropLast().joined(separator: " ")

        if let book = BibleData.books.first(where: { $0.name.compare(bookRaw, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return ScriptureRef(bookName: book.name, chapter: chapterNum, startVerse: verseNum, endVerse: nil)
        }
        let collapsed = bookRaw.replacingOccurrences(of: " ", with: "")
        if let book = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return ScriptureRef(bookName: book.name, chapter: chapterNum, startVerse: verseNum, endVerse: nil)
        }
        let spacedLeading: String
        if let first = bookRaw.first, first.isNumber {
            let digits = String(bookRaw.prefix { $0.isNumber })
            let rest = String(bookRaw.drop { $0.isNumber })
            spacedLeading = digits + " " + rest
        } else {
            spacedLeading = bookRaw
        }
        if let book = BibleData.books.first(where: { $0.name.compare(spacedLeading, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return ScriptureRef(bookName: book.name, chapter: chapterNum, startVerse: verseNum, endVerse: nil)
        }
        return nil
    }

    // MARK: - On-screen keyboard

    private func keyboardView(keyHeight: CGFloat) -> some View {
        HangmanKeyboardView(
            usesAlphabeticalLayout: $useAlphabeticalLayout,
            guessedLetters: guessedLetters,
            correctLetters: correctLetters,
            wrongLetters: wrongLetters,
            isRoundOver: roundOver,
            keyHeight: keyHeight,
            onGuess: guess
        )
    }
}

private struct HangmanSetupControls: View {
    @Binding var theme: HangmanGameView.Theme

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Choose word types", systemImage: "text.word.spacing")
                .font(.headline)
                .foregroundStyle(.teal)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(HangmanGameView.Theme.allCases) { option in
                    let isSelected = theme == option

                    Button {
                        theme = option
                    } label: {
                        themeCard(option, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal)
    }

    private func themeCard(
        _ option: HangmanGameView.Theme,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: option.systemImage)
                .foregroundStyle(isSelected ? .white : .teal)
            Text(option.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
            Text(option.detail)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            isSelected ? Color.teal : Color.teal.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.teal : .clear, lineWidth: 2)
        }
    }
}

private struct HangmanRevealCard: View {
    let didWin: Bool
    let answer: String
    let qualifier: String?
    let clue: String
    let reference: String?
    let onShowReference: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                didWin ? "You got it!" : "Out of guesses",
                systemImage: didWin ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(didWin ? Color.green : Color.red)

            if let qualifier {
                Text("\(answer) (\(qualifier))")
                    .font(.title3.weight(.bold))
            } else {
                Text(answer)
                    .font(.title3.weight(.bold))
            }

            if !clue.isEmpty {
                Text(clue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let reference {
                Button {
                    onShowReference(reference)
                } label: {
                    Label(reference, systemImage: "book.closed")
                }
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                .accessibilityHint("Shows the scripture passage")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            (didWin ? Color.green : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct HangmanResultsCard: View {
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
                .foregroundStyle(isNewBest ? Color.yellow : Color.teal)

            VStack(spacing: 6) {
                Text(isNewBest ? "New Best Game!" : "Game Over")
                    .font(.title.weight(.bold))

                Text("\(score) of \(total) words solved")
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
                    .buttonStyle(GameProminentButtonStyle(tint: .teal))

                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .heroCardSurface()
    }
}

private struct HangmanKeyboardView: View {
    @Binding var usesAlphabeticalLayout: Bool
    let guessedLetters: Set<Character>
    let correctLetters: Set<Character>
    let wrongLetters: Set<Character>
    let isRoundOver: Bool
    let keyHeight: CGFloat
    let onGuess: (Character) -> Void

    private var rows: [[Character]] {
        let layout = usesAlphabeticalLayout
            ? ["ABCDEFG", "HIJKLMN", "OPQRSTU", "VWXYZ"]
            : ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
        return layout.map(Array.init)
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex], id: \.self) { character in
                        let upper = Character(String(character).uppercased())
                        Button {
                            onGuess(upper)
                        } label: {
                            Text(String(character))
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: keyHeight)
                                .accessibilityLabel("Letter \(String(character))")
                        }
                        .buttonStyle(GameKeyButtonStyle(tint: tint(for: upper)))
                        // Not .disabled: that would grey out the green and red played keys.
                        .allowsHitTesting(!guessedLetters.contains(upper) && !isRoundOver)
                        .opacity(isRoundOver ? 0.6 : 1)
                        .accessibilityValue(keyState(for: upper))

                        if !usesAlphabeticalLayout,
                           rowIndex == rows.count - 1,
                           character == "M" {
                            layoutToggle(title: "A-Z")
                        }
                    }

                    if usesAlphabeticalLayout, rowIndex == rows.count - 1 {
                        layoutToggle(title: "QWERTY")
                    }
                }
            }
        }
    }

    private func keyState(for character: Character) -> String {
        if correctLetters.contains(character) { return String(localized: "In the word") }
        if wrongLetters.contains(character) { return String(localized: "Not in the word") }
        return ""
    }

    private func tint(for character: Character) -> Color {
        if correctLetters.contains(character) {
            return .green
        }
        return wrongLetters.contains(character) ? .red : .accentColor
    }

    private func layoutToggle(title: String) -> some View {
        Button {
            usesAlphabeticalLayout.toggle()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .accessibilityLabel("Toggle keyboard layout")
        }
        .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
        .disabled(isRoundOver)
        .opacity(isRoundOver ? 0.6 : 1)
    }
}

private struct HangmanResponsiveLayout<
    Header: View,
    Word: View,
    Drawing: View,
    Scoreboard: View,
    Keyboard: View
>: View {
    let usesWideLayout: Bool
    let availableHeight: CGFloat
    let showsKeyboardCard: Bool
    let showsHangmanCardFirst: Bool
    let toggleKeyboardCard: () -> Void
    let swapCards: () -> Void
    let header: Header
    let word: Word
    let drawing: Drawing
    let scoreboard: Scoreboard
    let keyboard: Keyboard

    init(
        usesWideLayout: Bool,
        availableHeight: CGFloat,
        showsKeyboardCard: Bool,
        showsHangmanCardFirst: Bool,
        toggleKeyboardCard: @escaping () -> Void,
        swapCards: @escaping () -> Void,
        @ViewBuilder header: () -> Header,
        @ViewBuilder word: () -> Word,
        @ViewBuilder drawing: () -> Drawing,
        @ViewBuilder scoreboard: () -> Scoreboard,
        @ViewBuilder keyboard: () -> Keyboard
    ) {
        self.usesWideLayout = usesWideLayout
        self.availableHeight = availableHeight
        self.showsKeyboardCard = showsKeyboardCard
        self.showsHangmanCardFirst = showsHangmanCardFirst
        self.toggleKeyboardCard = toggleKeyboardCard
        self.swapCards = swapCards
        self.header = header()
        self.word = word()
        self.drawing = drawing()
        self.scoreboard = scoreboard()
        self.keyboard = keyboard()
    }

    var body: some View {
        if usesWideLayout {
            let mainCardHeight = showsKeyboardCard
                ? max(360, availableHeight * 0.56)
                : max(600, availableHeight * 0.92)

            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
                    if showsHangmanCardFirst {
                        hangmanCard(height: mainCardHeight)
                        gameCard(height: mainCardHeight)
                    } else {
                        gameCard(height: mainCardHeight)
                        hangmanCard(height: mainCardHeight)
                    }
                }

                if showsKeyboardCard {
                    VStack(spacing: 14) {
                        keyboard
                    }
                    .padding(AppDesignMetrics.cardPadding)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(250, availableHeight * 0.32),
                        alignment: .top
                    )
                    .heroCardSurface()
                }
            }
            .frame(maxWidth: 1_180)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        } else {
            VStack(spacing: 12) {
                header
                scoreboard
                drawing
                word
                keyboard
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }

    private func gameCard(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                header
                Spacer(minLength: 8)
                Button(action: toggleKeyboardCard) {
                    Label(
                        showsKeyboardCard ? "Hide Keyboard" : "Show Keyboard",
                        systemImage: showsKeyboardCard
                            ? "keyboard.chevron.compact.down"
                            : "keyboard"
                    )
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer(minLength: 0)
            word
            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: height)
        .heroCardSurface()
    }

    private func hangmanCard(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            scoreboard

            HStack {
                Spacer()
                Button(action: swapCards) {
                    Label("Swap Cards", systemImage: "arrow.left.arrow.right")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Switches the game and hangman cards to opposite sides")
            }

            Spacer(minLength: 0)
            drawing
            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: height)
        .heroCardSurface()
    }
}

// MARK: - Hangman Drawing

private struct HangmanDrawing: View {
    let progress: Double
    let maximumCharacterHeight: CGFloat

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var fillColor: Color {
        if clampedProgress >= 0.75 { return .red }
        if clampedProgress >= 0.4 { return .orange }
        return .teal
    }

    var body: some View {
        GeometryReader { geo in
            let characterHeight = min(geo.size.height, maximumCharacterHeight)
            let characterWidth = min(geo.size.width * 0.72, characterHeight * 0.62)

            ZStack {
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.secondary.opacity(0.16))

                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(fillColor.gradient)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: characterHeight * clampedProgress)
                    }
            }
            .frame(width: characterWidth, height: characterHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.35), value: clampedProgress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mistake meter")
        .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent filled")
    }
}

#if canImport(UIKit)
private struct KeyCaptureRepresentable: UIViewRepresentable {
    var onKey: (Character) -> Void
    var onBackspace: () -> Void
    var onEnter: () -> Void

    final class KeyView: UIView {
        var onKey: ((Character) -> Void)?
        var onBackspace: (() -> Void)?
        var onEnter: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        // Claim hardware-keyboard focus once, when the view appears on screen.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                DispatchQueue.main.async { self.becomeFirstResponder() }
            }
        }

        override var keyCommands: [UIKeyCommand]? {
            var cmds: [UIKeyCommand] = []
            let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            for ch in letters {
                cmds.append(UIKeyCommand(input: String(ch), modifierFlags: [], action: #selector(handleKey(_:))))
                cmds.append(UIKeyCommand(input: String(ch.lowercased()), modifierFlags: [], action: #selector(handleKey(_:))))
            }
            cmds.append(UIKeyCommand(input: UIKeyCommand.inputDelete, modifierFlags: [], action: #selector(handleDelete)))
            cmds.append(UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleEnter)))
            cmds.append(UIKeyCommand(input: "\n", modifierFlags: [], action: #selector(handleEnter)))
            return cmds
        }

        @objc private func handleKey(_ sender: UIKeyCommand) {
            guard let s = sender.input, let first = s.uppercased().first, first.isLetter else { return }
            onKey?(first)
        }

        @objc private func handleDelete() { onBackspace?() }
        @objc private func handleEnter() { onEnter?() }
    }

    func makeUIView(context: Context) -> KeyView {
        let v = KeyView()
        v.isUserInteractionEnabled = false
        v.onKey = onKey
        v.onBackspace = onBackspace
        v.onEnter = onEnter
        return v
    }

    func updateUIView(_ uiView: KeyView, context: Context) {
        uiView.onKey = onKey
        uiView.onBackspace = onBackspace
        uiView.onEnter = onEnter
    }
}
#endif
