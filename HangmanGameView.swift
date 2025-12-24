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

    @State private var theme: Theme = .all
    @State private var difficulty: Difficulty = .normal

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

    private var allTimeCorrect: Int {
        let key = "hangmanAllTimeCorrect_\(difficultyKeySuffix())"
        return UserDefaults.standard.integer(forKey: key)
    }
    private var allTimeAnswered: Int {
        let key = "hangmanAllTimeAnswered_\(difficultyKeySuffix())"
        return UserDefaults.standard.integer(forKey: key)
    }
    private var allTimeBestStreak: Int {
        let key = "hangmanAllTimeBestStreak_\(difficultyKeySuffix())"
        return UserDefaults.standard.integer(forKey: key)
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

                    inGameSection

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
        .fontDesign(appFontDesign)
        .navigationTitle("Hangman")
        .navigationBarTitleDisplayMode(.inline)
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
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 8) {
            GroupBox {
                DisclosureGroup(isExpanded: $howToExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Easy: Up to 10 mistakes. A scripture reference is shown right away to help.")
                        Text("• Normal: Up to 7 mistakes. The reference appears after 3 wrong guesses.")
                        Text("• Hard: Up to 6 mistakes. The reference is shown only after the round ends.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Difficulty Levels").font(.headline)
                }
            }
        }
        .padding(.horizontal)

        Picker("Theme", selection: $theme) {
            ForEach(Theme.allCases) { t in
                Text(t.rawValue).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        Picker("Difficulty", selection: $difficulty) {
            ForEach(Difficulty.allCases) { d in
                Text(d.rawValue).tag(d)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        Button("Start") { startGame() }
            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            .controlSize(.large)
            .frame(maxWidth: 240)
        Spacer(minLength: 24)
    }

    @ViewBuilder
    private var inGameSection: some View {
        roundHeader

        GameScoreboardCard(
            currentCorrect: score,
            currentAnswered: answered,
            currentStreak: currentStreak,
            allTimeCorrect: allTimeCorrect,
            allTimeAnswered: allTimeAnswered,
            allTimeBestStreak: allTimeBestStreak
        )

        HangmanDrawing(
            revealedCount: piecesRevealed(),
            totalPieces: 10
        )
        .frame(height: drawingHeight)
        .padding(.top, 0)

        Text(spacedDisplayWord())
            .font(.system(size: 28, weight: .semibold, design: .monospaced))
            .fontDesign(appFontDesign)
            .padding(.top, 4)
            .accessibilityLabel("Word to guess")

        Text("Mistakes: \(wrongGuesses)/\(maxWrong)")
            .font(.subheadline)
            .foregroundStyle(wrongGuesses >= maxWrong - 1 ? .red : .secondary)

        keyboardView()
            .padding(.top, 8)

        if roundOver {
            Text(didWin ? "You got it!" : "Out of guesses: \(targetWord.uppercased())")
                .font(.headline)
                .foregroundStyle(didWin ? .green : .red)
                .padding(.top, 6)
        }
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
                }
                .buttonStyle(ModernPillButtonStyle(tint: .blue))
                .controlSize(.small)
            }

            Button("Previous") { showPreviousSheet = true }
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                .controlSize(.small)
                .disabled(history.isEmpty)
                .opacity(history.isEmpty ? 0.5 : 1.0)

            if roundOver {
                Button("Next") { nextRound() }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func previousRoundSheet() -> some View {
        if let last = history.last {
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
                    .buttonStyle(ModernPillButtonStyle(tint: .blue))
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

    private func piecesRevealed() -> Int {
        let clampedMax = max(1, maxWrong)
        let fraction = Double(min(wrongGuesses, clampedMax)) / Double(clampedMax)
        let totalPieces = 10
        let count = Int(round(fraction * Double(totalPieces)))
        return max(0, min(totalPieces, count))
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
            // Keep session best in sync
            currentBestStreak = max(currentBestStreak, persisted, readPersistentBest())

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            GameStats.shared.recordRound(
                game: .hangman,
                difficulty: mapDifficulty(difficulty),
                correct: 1,
                answered: 1,
                currentBestStreak: currentBestStreak
            )
        } else {
            // Persistent streak: reset on loss
            writePersistentStreak(0)
            currentStreak = 0

            GameStats.shared.recordRound(
                game: .hangman,
                difficulty: mapDifficulty(difficulty),
                correct: 0,
                answered: 1,
                currentBestStreak: currentBestStreak
            )
        }
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

    private func capitalize(_ s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased() + s.dropFirst().lowercased()
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

    private func keyboardView() -> some View {
        let keyFontSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 22 : 18
        let keyMinWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 44 : 36
        let keyMinHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 48 : 42
        let keySpacing: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 10 : 9
        let rowSpacing: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 12 : 10

        let qwertyRows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
        let alphaRows = ["ABCDEFG", "HIJKLMN", "OPQRSTU", "VWXYZ"]

        let rows: [[Character]] = {
            if useAlphabeticalLayout {
                return alphaRows.map { Array($0) }
            } else {
                return qwertyRows.map { Array($0) }
            }
        }()

        return VStack(spacing: rowSpacing) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                let rowChars = rows[rowIndex]
                HStack(spacing: keySpacing) {
                    ForEach(rowChars, id: \.self) { ch in
                        let upper = Character(String(ch).uppercased())
                        let isGuessed = guessedLetters.contains(upper)
                        let tint: Color = {
                            if correctLetters.contains(upper) { return .green }
                            if wrongLetters.contains(upper) { return .red }
                            return .accentColor
                        }()

                        Button(action: { guess(upper) }) {
                            Text(String(ch))
                                .font(.system(size: keyFontSize, weight: .semibold))
                                .frame(minWidth: keyMinWidth, minHeight: keyMinHeight)
                                .accessibilityLabel("Letter \(String(ch))")
                        }
                        .buttonStyle(SolidKeyButtonStyle(tint: tint))
                        .disabled(isGuessed || roundOver)
                        .opacity(roundOver ? 0.6 : 1.0)

                        if !useAlphabeticalLayout {
                            if rowIndex == rows.count - 1, ch == "M" {
                                layoutToggleButton(
                                    title: "A-Z",
                                    keyFontSize: keyFontSize,
                                    keyMinWidth: keyMinWidth,
                                    keyMinHeight: keyMinHeight
                                )
                            }
                        }
                    }

                    if useAlphabeticalLayout {
                        if rowIndex == rows.count - 1 {
                            layoutToggleButton(
                                title: "QWERTY",
                                keyFontSize: keyFontSize,
                                keyMinWidth: keyMinWidth,
                                keyMinHeight: keyMinHeight
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func layoutToggleButton(title: String, keyFontSize: CGFloat, keyMinWidth: CGFloat, keyMinHeight: CGFloat) -> some View {
        Button(action: { useAlphabeticalLayout.toggle() }) {
            Text(title)
                .font(.system(size: keyFontSize - 2, weight: .semibold))
                .frame(minWidth: keyMinWidth + 6, minHeight: keyMinHeight)
                .accessibilityLabel("Toggle keyboard layout")
        }
        .buttonStyle(SolidKeyButtonStyle(tint: .secondary))
        .disabled(roundOver)
        .opacity(roundOver ? 0.6 : 1.0)
    }
}

// MARK: - Solid key style for Hangman (filled color keys)
private struct SolidKeyButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(pressed ? 0.06 : 0.12), radius: pressed ? 1 : 2, x: 0, y: pressed ? 0 : 1)
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

// MARK: - Hangman Drawing

private struct HangmanDrawing: View {
    let revealedCount: Int
    let totalPieces: Int

    @Environment(\.colorScheme) private var scheme

    private var stroke: Color {
        scheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.85)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Tight virtual width (64); height 140
            let scaleX = w / 64.0
            let scaleY = h / 140.0

            ZStack {
                Group {
                    if revealedCount >= 1 { base(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 2 { pole(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 3 { beam(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 4 { rope(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 5 { head(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 6 { torso(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 7 { leftArm(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 8 { rightArm(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 9 { leftLeg(scaleX: scaleX, scaleY: scaleY) }
                    if revealedCount >= 10 { rightLeg(scaleX: scaleX, scaleY: scaleY) }
                }
                .animation(.easeInOut(duration: 0.25), value: revealedCount)
            }
            .frame(width: w, height: h)
        }
    }

    // Base: shorter but still connected to the pole at x=16 (end from 38 -> 34).
    private func base(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 16 * scaleX, y: 130 * scaleY))
            p.addLine(to: CGPoint(x: 34 * scaleX, y: 130 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
        .transition(.opacity)
    }

    // Pole at x=16
    private func pole(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 16 * scaleX, y: 130 * scaleY))
            p.addLine(to: CGPoint(x: 16 * scaleX, y: 24 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
        .transition(.opacity)
    }

    // Beam cut in half: 16 → 32
    private func beam(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 16 * scaleX, y: 24 * scaleY))
            p.addLine(to: CGPoint(x: 32 * scaleX, y: 24 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
        .transition(.opacity)
    }

    // Rope at x=32
    private func rope(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 32 * scaleX, y: 24 * scaleY))
            p.addLine(to: CGPoint(x: 32 * scaleX, y: 38 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        .transition(.opacity)
    }

    // Head centered at x=32 — make a little bigger (diameter 16 instead of 14)
    private func head(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Circle()
            .stroke(stroke, lineWidth: 2.6)
            .frame(width: 16 * scaleX, height: 16 * scaleY)
            .position(x: 32 * scaleX, y: 46 * scaleY)
            .transition(.opacity)
    }

    private func torso(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 32 * scaleX, y: 54 * scaleY))
            p.addLine(to: CGPoint(x: 32 * scaleX, y: 88 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        .transition(.opacity)
    }

    // Arms shorter (endpoints moved slightly inward/up)
    private func leftArm(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 32 * scaleX, y: 62 * scaleY))
            p.addLine(to: CGPoint(x: 28.5 * scaleX, y: 68 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        .transition(.opacity)
    }

    private func rightArm(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 32 * scaleX, y: 62 * scaleY))
            p.addLine(to: CGPoint(x: 35.5 * scaleX, y: 68 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        .transition(.opacity)
    }

    // Legs shorter (endpoints moved slightly inward/up)
    private func leftLeg(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 32 * scaleX, y: 88 * scaleY))
            p.addLine(to: CGPoint(x: 29 * scaleX, y: 98 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        .transition(.opacity)
    }

    private func rightLeg(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 32 * scaleX, y: 88 * scaleY))
            p.addLine(to: CGPoint(x: 35 * scaleX, y: 98 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        .transition(.opacity)
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
