import SwiftUI
import UIKit

struct HangmanGameView: View {
    // MARK: - Font design mapping based on Settings
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = "system"
    private var appFontDesign: Font.Design? {
        switch fontFamilyPreferenceRaw.lowercased() {
        case "serif", "georgia": return .serif
        case "rounded": return .rounded
        case "monospaced": return .monospaced
        default: return nil
        }
    }

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    enum Theme: String, CaseIterable, Identifiable {
        case all = "All"
        case people = "People"
        case places = "Places"
        case books = "Books"
        var id: String { rawValue }
    }
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "Easy"
        case normal = "Normal"   // was Medium
        case hard = "Hard"
        var id: String { rawValue }
        }

    @State private var started = false
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false

    @AppStorage("hangmanTheme") private var theme: Theme = .all
    @AppStorage("hangmanDifficulty") private var difficulty: Difficulty = .normal

    @State private var targetWord: String = ""
    @State private var displayWord: String = ""

    @State private var guessedLetters: Set<Character> = []
    @State private var correctLetters: Set<Character> = []
    @State private var wrongLetters: Set<Character> = []

    @State private var wrongGuesses: Int = 0
    @State private var maxWrong: Int = 7

    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var roundOver: Bool = false
    @State private var didWin: Bool = false

    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0

    // Always show aggregated all-time across difficulties
    private var allTimeCorrect: Int {
        UserDefaults.standard.integer(forKey: "hangmanAllTimeCorrect_all")
    }
    private var allTimeAnswered: Int {
        UserDefaults.standard.integer(forKey: "hangmanAllTimeAnswered_all")
    }
    private var allTimeBestStreak: Int {
        UserDefaults.standard.integer(forKey: "hangmanAllTimeBestStreak_all")
    }

    @State private var loadedPeople: [BibleName] = []
    @State private var loadedPlaces: [BibleLocation] = []

    @State private var navigateToReader: Bool = false
    @State private var navBook: Book? = nil
    @State private var navChapter: Chapter? = nil
    @State private var navStartVerse: Int = 1

    // Current round metadata used by UI and snapshot
    @State private var currentRoundCategory: Theme = .all
    @State private var currentTargetReference: String? = nil

    private struct HangmanSnapshot: Identifiable {
        let id = UUID()
        let category: Theme
        let targetWord: String
        let didWin: Bool
        let wrongGuesses: Int
        let maxWrong: Int
        let reference: String?
    }
    @State private var history: [HangmanSnapshot] = []
    @State private var showPreviousSheet: Bool = false

    // Smart link style preview state (mirror Wordle)
    @State private var showRefSheet: Bool = false
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil

    // Keyboard layout toggle: false = QWERTY, true = A-Z
    @State private var useAlphabeticalLayout: Bool = false
    @State private var showsOnScreenKeyboard: Bool = true
    @State private var showsHangmanCardFirst: Bool = false

    // MARK: - Persistent streak helpers (per difficulty)
    private func persistentKeys() -> (current: String, best: String) {
        let suf = difficultyKeySuffix()
        return ("hangmanPersistentStreak_\(suf)", "hangmanPersistentBestStreak_\(suf)")
    }
    private func readPersistentStreak() -> Int {
        let key = persistentKeys().current
        return max(0, UserDefaults.standard.integer(forKey: key))
    }
    private func writePersistentStreak(_ value: Int) {
        let v = max(0, value)
        let key = persistentKeys().current
        UserDefaults.standard.set(v, forKey: key)
        // Optional: push to iCloud KVS (local persistence requirement does not need it)
        iCloudSyncCoordinator.shared.pushKey(key)
    }
    private func readPersistentBest() -> Int {
        let key = persistentKeys().best
        return max(0, UserDefaults.standard.integer(forKey: key))
    }
    private func writePersistentBest(_ value: Int) {
        let v = max(0, value)
        let key = persistentKeys().best
        UserDefaults.standard.set(v, forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }
    private func seedStreakFromPersistence() {
        let persistedCurrent = readPersistentStreak()
        currentStreak = persistedCurrent
        // Keep session best at least as high as persisted best
        let persistedBest = readPersistentBest()
        currentBestStreak = max(currentBestStreak, persistedBest)
    }

    var body: some View {
        GeometryReader { geometry in
            let usesWideLayout = started && geometry.size.width >= 900

            ScrollView {
                VStack(spacing: 12) {
                    if !started {
                        startSection
                    } else {
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
                                    nextRound()
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

                        if debugAutoWinEnabled, started, !roundOver {
                            Button("WIN") {
                                endRound(win: true)
                            }
                            .buttonStyle(ModernPillButtonStyle(tint: .red))
                            .controlSize(.large)
                            .padding(.top, 6)
                            .accessibilityLabel("Win this round")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        .fontDesign(appFontDesign)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if started {
                    GameNavigationTitle(title: "Hangman", systemImage: "text.word.spacing", tint: .teal)
                }
            }
        }
        .onAppear {
            Task {
                if loadedPeople.isEmpty { loadedPeople = await GameDataLoaders.loadNamesAsync() }
                if loadedPlaces.isEmpty { loadedPlaces = await GameDataLoaders.loadLocationsAsync() }
            }
            // Seed streaks from persisted values (survive app relaunch/navigation)
            seedStreakFromPersistence()
        }
        .onChange(of: difficulty) { _, newValue in
            applyMaxWrong(for: newValue)
            // When difficulty changes, switch to that difficulty’s persisted streaks
            seedStreakFromPersistence()
        }
        .navigationDestination(isPresented: $navigateToReader) {
            if let book = navBook, let chapter = navChapter {
                ReadingView(book: book, chapter: chapter, startVerse: navStartVerse)
                    .id("\(book.name)-\(chapter.number)-\(navStartVerse)")
            }
        }
        .toolbar { }
        .sheet(isPresented: $showPreviousSheet) {
            previousRoundSheet()
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

        GameStartInfoLayout {
            GroupBox {
                DisclosureGroup(isExpanded: $howToExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("• Pick a theme and difficulty, then tap Start.")
                        Text("• Tap letters on the on‑screen keyboard to guess.")
                        Text("• You have a limited number of mistakes. Reveal the word before you run out!")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("How to Play").font(.headline)
                }
            }

            GroupBox {
                DisclosureGroup(isExpanded: $difficultyExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("• Easy: Up to 10 mistakes. A scripture reference is shown right away to help.")
                        Text("• Normal: Up to 7 mistakes. The reference appears after 3 wrong guesses.")
                        Text("• Hard: Up to 6 mistakes. The reference is shown only after the round ends.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Difficulty Settings").font(.headline)
                }
            }

            GameStartCurrentGameCard {
                GameStartCurrentGameRow(label: "Theme", value: theme.rawValue)
                GameStartCurrentGameRow(label: "Difficulty", value: difficulty.rawValue)
                GameStartCurrentGameRow(
                    label: "Round",
                    value: difficulty == .easy ? "10 mistakes · Reference shown" : difficulty == .normal ? "7 mistakes · Reference after 3 misses" : "6 mistakes · Reference after round"
                )
            }
        }
        .gameStartOptionsStyle()
        .padding(.horizontal)

        GameStartSettingsLayout {
            GameStartPickerCard(
                title: "Theme",
                selection: $theme,
                options: Theme.allCases
            ) { theme in
                Text(theme.rawValue)
            }

            GameStartPickerCard(
                title: "Difficulty",
                selection: $difficulty,
                options: Difficulty.allCases
            ) { difficulty in
                Text(difficulty.rawValue)
            }
        }
        .padding(.horizontal)

        GameLobbyPreview(kind: .hangman)

        GameStartActionBar(action: startGame)
        GameSetupSummary(
            summary: "You’ll guess \(theme.rawValue.lowercased()) from the Bible. You can miss up to \(maxWrong) letters, and \(difficulty == .easy ? "the scripture reference is shown immediately" : difficulty == .normal ? "the reference appears after three misses" : "the reference appears after the round")."
        )
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
                Text(spacedDisplayWord())
                    .font(.system(size: usesWideLayout ? 34 : 28, weight: .semibold, design: .monospaced))
                    .fontDesign(appFontDesign)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Word to guess")

                Text("Mistakes: \(wrongGuesses)/\(maxWrong)")
                    .font(.subheadline)
                    .foregroundStyle(wrongGuesses >= maxWrong - 1 ? .red : .secondary)

                if roundOver {
                    Text(didWin ? "You got it!" : "Out of guesses: \(targetWord.uppercased())")
                        .font(.headline)
                        .foregroundStyle(didWin ? .green : .red)
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
                currentStreak: currentStreak,
                game: .hangman,
                style: usesWideLayout ? .dashboard : .compact
            )
        } keyboard: {
            if roundOver {
                GameRoundNavigationButtons(
                    canGoPrevious: history.count > 1,
                    canGoNext: true,
                    onPrevious: { showPreviousSheet = true },
                    onNext: { nextRound() }
                )
                .padding(.horizontal, 6)
                .padding(.top, 8)
            } else {
                keyboardView(keyHeight: usesWideLayout ? 60 : 42)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
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
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: currentRoundCategory))
                Text(currentRoundCategory.rawValue.uppercased())
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                categoryTint(for: currentRoundCategory).opacity(0.18),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(categoryTint(for: currentRoundCategory).opacity(0.45), lineWidth: 1)
            )
            .foregroundStyle(categoryTint(for: currentRoundCategory))

            Spacer(minLength: 6)

            if let ref = firstReferenceForCurrentTarget(), shouldShowReference() {
                Button {
                    presentReferencePreview(from: ref)
                } label: {
                    Text(ref)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(!roundOver)
                .accessibilityHint(
                    roundOver
                        ? "Shows the scripture passage"
                        : "Available after the round ends"
                )
                .foregroundStyle(Color.accentColor)
                .background(
                    Color.accentColor.opacity(0.14),
                    in: RoundedRectangle(
                        cornerRadius: AppDesignMetrics.compactControlCornerRadius,
                        style: .continuous
                    )
                )
                .heroCardSurface(cornerRadius: AppDesignMetrics.compactControlCornerRadius)
                .controlSize(.small)
            }

        }
    }

    @ViewBuilder
    private func previousRoundSheet() -> some View {
        if let last = history.dropLast().last {
            VStack(alignment: .leading, spacing: 12) {
                Text("Previous Round")
                    .font(.title3)
                    .bold()
                HStack(spacing: 8) {
                    Text("Category:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(last.category.rawValue)
                        .font(.subheadline)
                }
                HStack(spacing: 8) {
                    Text("Result:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(last.didWin ? "Correct" : "Out of guesses")
                        .font(.subheadline)
                        .foregroundStyle(last.didWin ? .green : .red)
                }
                HStack(spacing: 8) {
                    Text("Answer:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(last.targetWord)
                        .font(.headline)
                }
                HStack(spacing: 8) {
                    Text("Mistakes:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(last.wrongGuesses)/\(last.maxWrong)")
                        .font(.subheadline)
                }
                if let ref = last.reference {
                    Divider()
                    Button {
                        presentReferencePreview(from: ref)
                        showPreviousSheet = false
                    } label: {
                        Text(ref)
                            .lineLimit(1)
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.small)
                }
                Spacer()
                HStack { Spacer(); Button("Close") { showPreviousSheet = false } }
            }
            .padding()
            .presentationDetents([.medium])
        } else {
            Text("No previous rounds")
                .padding()
        }
    }

    private var drawingHeight: CGFloat {
        // Smaller to emphasize tighter proportions
        UIDevice.current.userInterfaceIdiom == .pad ? 130 : 100
    }

    private func applyMaxWrong(for d: Difficulty) {
        switch d {
        case .easy: maxWrong = 10
        case .normal: maxWrong = 7
        case .hard: maxWrong = 6
        }
        if wrongGuesses >= maxWrong && started && !roundOver {
            endRound(win: false)
        }
    }

    private func iconName(for theme: Theme) -> String {
        switch theme {
        case .places: return "house.fill"
        case .people: return "person.fill"
        case .books: return "book.fill"
        case .all: return "tag.fill"
        }
    }

    private func categoryTint(for theme: Theme) -> Color {
        switch theme {
        case .people: return .orange
        case .places: return .orange
        case .books: return .orange
        case .all: return .orange
        }
    }

    private func startGame() {
        if loadedPeople.isEmpty || loadedPlaces.isEmpty {
            Task {
                if loadedPeople.isEmpty { loadedPeople = await GameDataLoaders.loadNamesAsync() }
                if loadedPlaces.isEmpty { loadedPlaces = await GameDataLoaders.loadLocationsAsync() }
                score = 0
                answered = 0
                correctLetters.removeAll()
                wrongLetters.removeAll()
                // Do NOT reset streaks here; they persist across sessions
                started = true
                applyMaxWrong(for: difficulty)
                // Ensure we seed from persistence right as we start
                seedStreakFromPersistence()
                nextRound()
            }
            return
        }
        score = 0
        answered = 0
        correctLetters.removeAll()
        wrongLetters.removeAll()
        // Do NOT reset streaks here; they persist across sessions
        started = true
        applyMaxWrong(for: difficulty)
        seedStreakFromPersistence()
        nextRound()
    }

    private func nextRound(resetScore: Bool = false) {
        guessedLetters = []
        wrongGuesses = 0
        correctLetters.removeAll()
        wrongLetters.removeAll()
        roundOver = false
        didWin = false
        applyMaxWrong(for: difficulty)
        generateRound()
    }

    private func spacedDisplayWord() -> String {
        displayWord.map { String($0) }.joined(separator: " ")
    }

    private func guess(_ ch: Character) {
        guard !roundOver else { return }
        let upper = Character(String(ch).uppercased())
        guard upper.isLetter else { return }
        guard !guessedLetters.contains(upper) else { return }
        guessedLetters.insert(upper)

        let light = UIImpactFeedbackGenerator(style: .light)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)

        let upperTarget = targetWord.uppercased()
        if upperTarget.contains(upper) {
            var chars = Array(displayWord)
            for (i, t) in upperTarget.enumerated() {
                if t == upper {
                    let originalChar = targetWord[targetWord.index(targetWord.startIndex, offsetBy: i)]
                    chars[i] = Character(String(originalChar).uppercased())
                }
            }
            displayWord = String(chars)
            correctLetters.insert(upper)
            light.impactOccurred()
            checkWin()
        } else {
            wrongLetters.insert(upper)
            heavy.impactOccurred()
            wrongGuesses += 1
            if wrongGuesses >= maxWrong {
                endRound(win: false)
            }
        }
    }

    private func checkWin() {
        if !displayWord.contains("_") {
            endRound(win: true)
        }
    }

    private func endRound(win: Bool) {
        roundOver = true
        didWin = win
        showsOnScreenKeyboard = true

        let snapshot = HangmanSnapshot(
            category: currentRoundCategory,
            targetWord: targetWord,
            didWin: win,
            wrongGuesses: wrongGuesses,
            maxWrong: maxWrong,
            reference: firstReferenceForCurrentTarget()
        )
        history.append(snapshot)

        answered += 1
        if win { score += 1 }

        // Persistent streak updates
        if win {
            // Persistent streak: increment on win
            let persisted = readPersistentStreak() + 1
            writePersistentStreak(persisted)
            currentStreak = persisted

            // Update persistent best if needed
            let bestPersisted = readPersistentBest()
            if persisted > bestPersisted {
                writePersistentBest(persisted)
            }
            currentBestStreak = max(currentBestStreak, persisted, readPersistentBest())

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            // Persistent streak: reset on loss
            writePersistentStreak(0)
            currentStreak = 0
        }

        // Record all-time round
        GameStats.shared.recordRound(
            game: .hangman,
            difficulty: mapDifficulty(difficulty),
            correct: win ? 1 : 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )

        // NEW: Record per-category (People/Places/Books) accuracy
        if currentRoundCategory != .all {
            GameStats.shared.recordHangmanCategory(
                category: currentRoundCategory.rawValue,
                answered: 1,
                correct: win ? 1 : 0
            )
        }

        // Keep rest of end-of-round flow (reference, etc.) unchanged
    }

    private func difficultyKeySuffix() -> String {
        switch difficulty {
        case .easy: return "easy"
        case .normal: return "normal"
        case .hard: return "hard"
        }
    }

    private func mapDifficulty(_ d: Difficulty) -> GameStats.Difficulty {
        switch d {
        case .easy: return .easy
        case .normal: return .medium
        case .hard: return .hard
        }
    }

    private func generateRound() {
        let actualCategory: Theme
        if theme == .all {
            actualCategory = [Theme.people, Theme.places, Theme.books].randomElement()!
        } else {
            actualCategory = theme
        }
        currentRoundCategory = actualCategory

        switch actualCategory {
        case .books:
            guard let book = BibleData.books.randomElement() else { return }
            targetWord = book.name
            displayWord = masked(from: targetWord)
            if displayWord.isEmpty {
                displayWord = masked(from: targetWord)
            }
            currentTargetReference = nil
        case .people:
            if loadedPeople.isEmpty { loadedPeople = GameDataLoaders.loadNames() }
            guard let entry = loadedPeople.randomElement() else { return }
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            targetWord = name
            displayWord = masked(from: targetWord)
            if displayWord.isEmpty {
                displayWord = masked(from: targetWord)
            }
            currentTargetReference = entry.firstReference
        case .places:
            if loadedPlaces.isEmpty { loadedPlaces = GameDataLoaders.loadLocations() }
            guard !loadedPlaces.isEmpty else { return }
            var picked: String? = nil
            for _ in 0..<50 {
                if let entry = loadedPlaces.randomElement() {
                    let loc = entry.location.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !loc.isEmpty {
                        picked = loc
                        break
                    }
                }
            }
            guard let loc = picked else { return }
            targetWord = loc
            displayWord = masked(from: targetWord)
            if displayWord.isEmpty {
                displayWord = masked(from: targetWord)
            }
            currentTargetReference = loadedPlaces.first { $0.location.caseInsensitiveCompare(targetWord) == .orderedSame }?.firstReference
        case .all:
            break
        }
    }

    private func masked(from word: String) -> String {
        String(word.map { ch in
            ch.isLetter ? "_" : String(ch)
        }.joined())
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "0%" }
        let pct = Int(round((Double(correct) / Double(answered)) * 100.0))
        return "\(pct)%"
    }

    private func shouldShowReference() -> Bool {
        switch difficulty {
        case .easy:
            return started && !targetWord.isEmpty && !displayWord.isEmpty
        case .normal:
            return roundOver || wrongGuesses >= 3
        case .hard:
            return roundOver
        }
    }

    private func firstReferenceForCurrentTarget() -> String? {
        return currentTargetReference
    }

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

    @ViewBuilder
    private func layoutToggleButton(title: String, keyHeight: CGFloat) -> some View {
        Button(action: { useAlphabeticalLayout.toggle() }) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .accessibilityLabel("Toggle keyboard layout")
        }
        .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
        .disabled(roundOver)
        .opacity(roundOver ? 0.6 : 1.0)
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
                        .allowsHitTesting(!guessedLetters.contains(upper) && !isRoundOver)
                        .opacity(isRoundOver ? 0.6 : 1)

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
        DispatchQueue.main.async { v.becomeFirstResponder() }
        return v
    }

    func updateUIView(_ uiView: KeyView, context: Context) {
        uiView.onKey = onKey
        uiView.onBackspace = onBackspace
        uiView.onEnter = onEnter
        DispatchQueue.main.async { uiView.becomeFirstResponder() }
    }
}
#endif
