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

    // MARK: - Debug/Test: Force Jesus Round toggle (shared across games)
    @AppStorage("forceJesusTestEnabled") private var forceJesusTestEnabled: Bool = false
    @State private var showJesusAlert: Bool = false

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

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !started {
                    startSection
                } else {
                    inGameSection
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
        }
        .onChange(of: difficulty) { _, newValue in
            applyMaxWrong(for: newValue)
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
        // Smart link style scripture preview sheet (like Wordle)
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
                            onClose: {
                                showRefSheet = false
                            }
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
            // Lazily load when a new ref is selected, ensuring the sheet presents on first tap
            .task(id: selectedRef) {
                guard let sr = selectedRef else { return }
                loadedPreview = BibleReferenceLinker.loadVerses(for: sr)
            }
        }
        .alert("Jesus Saves", isPresented: $showJesusAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    // MARK: - Sections extracted to reduce type-checking complexity

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

        // Debug/Test toggle
        Toggle("Force Jesus Round (Test)", isOn: $forceJesusTestEnabled)
            .tint(.orange)
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

        // Small hint under the word
        Text("Tap the letters to guess")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 2)

        Text("Mistakes: \(wrongGuesses)/\(maxWrong)")
            .font(.subheadline)
            .foregroundStyle(wrongGuesses >= maxWrong - 1 ? .red : .secondary)

        // On-screen keyboard (QWERTY, like Wordle)
        keyboardView()
            .padding(.top, 6)

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

            // Reference chip: show like Wordle (after round ends), present smart preview
            if let ref = firstReferenceForCurrentTarget(), roundOver {
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
        UIDevice.current.userInterfaceIdiom == .pad ? 150 : 120
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
                currentStreak = 0
                currentBestStreak = 0
                started = true
                applyMaxWrong(for: difficulty)
                nextRound()
            }
            return
        }
        score = 0
        answered = 0
        correctLetters.removeAll()
        wrongLetters.removeAll()
        currentStreak = 0
        currentBestStreak = 0
        started = true
        applyMaxWrong(for: difficulty)
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
            currentStreak += 1
            if currentStreak > currentBestStreak {
                currentBestStreak = currentStreak
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            GameStats.shared.recordRound(
                game: .hangman,
                difficulty: mapDifficulty(difficulty),
                correct: 1,
                answered: 1,
                currentBestStreak: currentBestStreak
            )
            if isJesusName(targetWord) {
                showJesusAlert = true
            }
        } else {
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
        case .normal: return "medium"
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
        if forceJesusTestEnabled {
            currentRoundCategory = .people
            targetWord = "Jesus"
            displayWord = masked(from: targetWord)
            if loadedPeople.isEmpty { loadedPeople = GameDataLoaders.loadNames() }
            if let entry = loadedPeople.first(where: { isJesusName($0.name) }) {
                currentTargetReference = entry.firstReference
            } else {
                currentTargetReference = nil
            }
            return
        }

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

    // Present immediately; load lazily inside the sheet
    private func presentReferencePreview(from refString: String) {
        selectedRef = parseScriptureRef(from: refString)
        loadedPreview = nil
        showRefSheet = true
    }

    private func parseScriptureRef(from ref: String) -> ScriptureRef? {
        // Preferred path: use the robust linker (handles abbreviations, spacing, hyphens)
        let attributed = BibleReferenceLinker.linkify(ref)
        for run in attributed.runs {
            if let url = run.attributes.link, let parsed = BibleReferenceLinker.parse(url: url) {
                return parsed
            }
        }

        // Fallback: simple manual parse with best-effort book resolution
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

        // Try exact book match
        if let book = BibleData.books.first(where: { $0.name.compare(bookRaw, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return ScriptureRef(bookName: book.name, chapter: chapterNum, startVerse: verseNum, endVerse: nil)
        }
        // Try collapsed spaces match
        let collapsed = bookRaw.replacingOccurrences(of: " ", with: "")
        if let book = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return ScriptureRef(bookName: book.name, chapter: chapterNum, startVerse: verseNum, endVerse: nil)
        }
        // Try inserting a space between leading digits and letters ("1John" -> "1 John")
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

    // MARK: - Jesus detection helper
    private func isJesusName(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        return lower == "jesus" || lower == "jesus christ"
    }

    // MARK: - On-screen keyboard

    private func keyboardView() -> some View {
        let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
        return VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(Array(row), id: \.self) { ch in
                        let upper = Character(String(ch).uppercased())
                        let isGuessed = guessedLetters.contains(upper)
                        let tint: Color = {
                            if correctLetters.contains(upper) { return .green }
                            if wrongLetters.contains(upper) { return .gray }
                            return .accentColor
                        }()

                        Button(action: { guess(upper) }) {
                            Text(String(ch))
                                .font(.system(size: 16, weight: .semibold))
                                .frame(minWidth: 28, minHeight: 36)
                                .accessibilityLabel("Letter \(String(ch))")
                        }
                        .buttonStyle(SolidKeyButtonStyle(tint: tint))
                        .disabled(isGuessed || roundOver)
                        .opacity(roundOver ? 0.6 : 1.0)
                    }
                }
            }
        }
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
            let scaleX = w / 100.0
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

    private func base(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 10 * scaleX, y: 130 * scaleY))
            p.addLine(to: CGPoint(x: 90 * scaleX, y: 130 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .transition(.opacity)
    }

    private func pole(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 25 * scaleX, y: 130 * scaleY))
            p.addLine(to: CGPoint(x: 25 * scaleX, y: 20 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .transition(.opacity)
    }

    private func beam(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 25 * scaleX, y: 20 * scaleY))
            p.addLine(to: CGPoint(x: 70 * scaleX, y: 20 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .transition(.opacity)
    }

    private func rope(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 70 * scaleX, y: 20 * scaleY))
            p.addLine(to: CGPoint(x: 70 * scaleX, y: 35 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .transition(.opacity)
    }

    private func head(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Circle()
            .stroke(stroke, lineWidth: 3)
            .frame(width: 18 * scaleX, height: 18 * scaleY)
            .position(x: 70 * scaleX, y: 45 * scaleY)
            .transition(.opacity)
    }

    private func torso(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 70 * scaleX, y: 54 * scaleY))
            p.addLine(to: CGPoint(x: 70 * scaleX, y: 88 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .transition(.opacity)
    }

    private func leftArm(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 70 * scaleX, y: 62 * scaleY))
            p.addLine(to: CGPoint(x: 58 * scaleX, y: 74 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .transition(.opacity)
    }

    private func rightArm(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 70 * scaleX, y: 62 * scaleY))
            p.addLine(to: CGPoint(x: 82 * scaleX, y: 74 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .transition(.opacity)
    }

    private func leftLeg(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 70 * scaleX, y: 88 * scaleY))
            p.addLine(to: CGPoint(x: 60 * scaleX, y: 106 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .transition(.opacity)
    }

    private func rightLeg(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 70 * scaleX, y: 88 * scaleY))
            p.addLine(to: CGPoint(x: 80 * scaleX, y: 106 * scaleY))
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .transition(.opacity)
    }
}
