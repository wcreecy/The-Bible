import SwiftUI
import UIKit

struct HangmanGameView: View {
    // MARK: - Consistent modern button styles for games
    private struct GameKeyButtonStyle: ButtonStyle {
        var tint: Color
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(tint)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(configuration.isPressed ? 0.22 : 0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: configuration.isPressed ? 2 : 1)
                )
                .shadow(color: .black.opacity(0.05), radius: configuration.isPressed ? 1 : 2, x: 0, y: configuration.isPressed ? 0 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
        }
    }

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

    enum Theme: String, CaseIterable, Identifiable {
        case all = "All"
        case people = "People"
        case places = "Places"
        case books = "Books"
        var id: String { rawValue }
    }
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        var id: String { rawValue }
    }

    @State private var started = false
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false

    @State private var theme: Theme = .all
    @State private var difficulty: Difficulty = .medium

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

    @State private var currentRoundCategory: Theme = .books
    @State private var tappedKey: Character? = nil
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

    private let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 32)
                    Text("Guess the person, place or book from the Bible")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Pick a theme and difficulty, then tap Start.")
                                    Text("• Guess letters using the on-screen keyboard (hardware keyboard is supported on iPad).")
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
                                    Text("• Easy: A scripture reference is shown during the round to help.")
                                    Text("• Medium: The reference appears after 3 wrong guesses.")
                                    Text("• Hard: The reference is only shown after the round ends.")
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
                    Spacer(minLength: 32)
                } else {
                    // Hidden text field to capture hardware keyboard input on iPad
                    TextField("", text: .constant(""))
                        .textInputAutocapitalization(.characters)
                        .keyboardType(.asciiCapable)
                        .opacity(0.001)
                        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification)) { note in
                            if let tf = note.object as? UITextField, let text = tf.text, let ch = text.last {
                                tf.text = ""
                                if ch.isLetter {
                                    guess(ch)
                                }
                            }
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            Spacer()
                            HStack(spacing: 8) {
                                Image(systemName: iconName(for: currentRoundCategory))
                                Text(currentRoundCategory.rawValue.uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                .ultraThinMaterial,
                                in: Capsule(style: .continuous)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
                            )
                            .foregroundStyle(.tint)
                        }

                        HStack(spacing: 8) {
                            if let ref = firstReferenceForCurrentTarget(), shouldShowReference() {
                                Button {
                                    if roundOver { openFirstReference(ref) }
                                } label: {
                                    Text(ref)
                                        .lineLimit(1)
                                }
                                .buttonStyle(ModernPillButtonStyle(tint: .blue))
                                .controlSize(.regular)
                                .disabled(!roundOver)
                                .opacity(roundOver ? 1.0 : 0.55)
                            }

                            Button("Previous") { showPreviousSheet = true }
                                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                                .controlSize(.regular)
                                .disabled(history.isEmpty)
                                .opacity(history.isEmpty ? 0.5 : 1.0)

                            if roundOver {
                                Button("Next") { nextRound() }
                                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                                    .controlSize(.regular)
                            }
                        }
                    }

                    GameScoreboardCard(
                        currentCorrect: score,
                        currentAnswered: answered,
                        currentStreak: currentStreak,
                        allTimeCorrect: allTimeCorrect,
                        allTimeAnswered: allTimeAnswered,
                        allTimeBestStreak: allTimeBestStreak
                    )

                    Text(spacedDisplayWord())
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .fontDesign(appFontDesign)
                        .padding(.top, 8)
                        .accessibilityLabel("Word to guess")

                    Text("Mistakes: \(wrongGuesses)/\(maxWrong)")
                        .font(.subheadline)
                        .foregroundStyle(wrongGuesses >= maxWrong - 1 ? .red : .secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                        ForEach(alphabet, id: \.self) { ch in
                            Button(action: {
                                withAnimation(.spring(response: 0.18, dampingFraction: 0.65)) {
                                    tappedKey = ch
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                        tappedKey = nil
                                    }
                                }
                                guess(ch)
                            }) {
                                Text(String(ch))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .disabled(guessedLetters.contains(ch) || roundOver)
                            .scaleEffect(tappedKey == ch ? 1.08 : 1.0)
                            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: tappedKey)
                            .buttonStyle(
                                GameKeyButtonStyle(
                                    tint: (
                                        correctLetters.contains(ch) ? .green : (
                                            wrongLetters.contains(ch) ? .red : .blue
                                        )
                                    )
                                )
                            )
                            .opacity((guessedLetters.contains(ch) || roundOver) ? 0.5 : 1.0)
                        }
                    }
                    .padding(.top, 6)

                    if roundOver {
                        Text(didWin ? "You got it!" : "Out of guesses: \(targetWord.uppercased())")
                            .font(.headline)
                            .foregroundStyle(didWin ? .green : .red)
                            .padding(.top, 8)
                    }
                }
            }
            .padding()
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
        .navigationDestination(isPresented: $navigateToReader) {
            if let book = navBook, let chapter = navChapter {
                ReadingView(book: book, chapter: chapter, startVerse: navStartVerse)
                    .id("\(book.name)-\(chapter.number)-\(navStartVerse)")
            }
        }
        .toolbar { }
        .sheet(isPresented: $showPreviousSheet) {
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
                            openFirstReference(ref)
                            showPreviousSheet = false
                        } label: {
                            Text(ref)
                                .lineLimit(1)
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .blue))
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
    }

    private func iconName(for theme: Theme) -> String {
        switch theme {
        case .places: return "house.fill"
        case .people: return "person.fill"
        case .books: return "book.fill"
        case .all: return "tag.fill"
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
        nextRound()
    }

    private func nextRound(resetScore: Bool = false) {
        guessedLetters = []
        wrongGuesses = 0
        correctLetters.removeAll()
        wrongLetters.removeAll()
        roundOver = false
        didWin = false
        generateRound()
    }

    private func spacedDisplayWord() -> String {
        displayWord.map { String($0) }.joined(separator: " ")
    }

    private func guess(_ ch: Character) {
        guard !roundOver else { return }
        let upper = Character(String(ch).uppercased())
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
            // Centralized write
            GameStats.shared.recordRound(
                game: .hangman,
                difficulty: mapDifficulty(difficulty),
                correct: 1,
                answered: 1,
                currentBestStreak: currentBestStreak
            )
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
        case .medium: return "medium"
        case .hard: return "hard"
        }
    }

    private func mapDifficulty(_ d: Difficulty) -> GameStats.Difficulty {
        switch d {
        case .easy: return .easy
        case .medium: return .medium
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

    @ViewBuilder
    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(tint)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
        )
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
        case .medium:
            return roundOver || wrongGuesses >= 3
        case .hard:
            return roundOver
        }
    }

    private func firstReferenceForCurrentTarget() -> String? {
        return currentTargetReference
    }

    private func openFirstReference(_ ref: String) {
        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split { $0.isWhitespace }
        guard let lastPart = parts.last else { return }
        var last = String(lastPart)
        last = last.replacingOccurrences(of: "\u{2013}", with: "-")
        last = last.replacingOccurrences(of: "\u{2014}", with: "-")
        last = last.trimmingCharacters(in: CharacterSet(charactersIn: ",;.)]”’\""))
        guard let colonIndex = last.firstIndex(of: ":") else { return }
        let chapterSlice = last[..<colonIndex]
        let verseSlice = last[last.index(after: colonIndex)...]
        let chapterDigits = chapterSlice.prefix { $0.isNumber }
        let verseDigits = verseSlice.prefix { $0.isNumber }
        guard let chapterNum = Int(chapterDigits), let verseNum = Int(verseDigits) else { return }
        let bookRaw = parts.dropLast().joined(separator: " ")
        guard let book = resolveBook(named: bookRaw) else { return }
        guard let chapter = book.chapters.first(where: { $0.number == chapterNum }) else { return }
        navBook = book
        navChapter = chapter
        navStartVerse = verseNum
        navigateToReader = true
    }

    private func resolveBook(named raw: String) -> Book? {
        if let direct = BibleData.books.first(where: { $0.name.caseInsensitiveCompare(raw) == .orderedSame }) {
            return direct
        }
        let spaced = insertSpaceBetweenLeadingDigitsAndLetters(in: raw)
        let normalized = normalizeBookName(spaced)
        if let match = BibleData.books.first(where: { $0.name.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match
        }
        let collapsed = normalized.replacingOccurrences(of: " ", with: "")
        if let match = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match
        }
        return nil
    }

    private func normalizeBookName(_ s: String) -> String {
        let abbrev: [String: String] = [
            "gen": "Genesis", "ex": "Exodus", "lev": "Leviticus", "num": "Numbers", "deut": "Deuteronomy",
            "jos": "Joshua", "judg": "Judges", "rut": "Ruth",
            "sam": "Samuel", "kgs": "Kings", "kg": "Kings", "chron": "Chronicles", "chr": "Chronicles",
            "ezr": "Ezra", "neh": "Nehemiah", "est": "Esther", "job": "Job", "ps": "Psalms", "psa": "Psalms",
            "prov": "Proverbs", "eccl": "Ecclesiastes", "song": "Song of Solomon", "so": "Song of Solomon",
            "isa": "Isaiah", "jer": "Jeremiah", "lam": "Lamentations", "eze": "Ezekiel", "dan": "Daniel",
            "hos": "Hosea", "joe": "Joel", "amo": "Amos", "oba": "Obadiah", "jon": "Jonah", "mic": "Micah",
            "nah": "Nahum", "hab": "Habakkuk", "zep": "Zephaniah", "hag": "Haggai", "zec": "Zechariah", "mal": "Malachi",
            "mat": "Matthew", "mk": "Mark", "mrk": "Mark", "lk": "Luke", "jn": "John", "jhn": "John",
            "act": "Acts", "rom": "Romans", "cor": "Corinthians", "gal": "Galatians", "eph": "Ephesians",
            "phil": "Philippians", "col": "Colossians", "thess": "Thessalonians", "tim": "Timothy", "tit": "Titus",
            "phm": "Philemon", "heb": "Hebrews", "jas": "James", "pet": "Peter", "petr": "Peter",
            "joh": "John", "jud": "Jude", "rev": "Revelation"
        ]
        let cleaned = s.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        var tokens = cleaned.split{ $0.isWhitespace }.map { String($0) }
        if let first = tokens.first, first.first?.isNumber == true, first.drop(while: { $0.isNumber }).first?.isLetter == true {
            let digits = String(first.prefix { $0.isNumber })
            let rest = String(first.drop { $0.isNumber })
            tokens[0] = digits
            if rest.isEmpty == false { tokens.insert(rest, at: 1) }
        }
        let mapped = tokens.enumerated().map { (idx, t) -> String in
            let lower = t.lowercased()
            if let exp = abbrev[lower] { return exp }
            if Int(lower) != nil { return t }
            return t.prefix(1).uppercased() + t.dropFirst().lowercased()
        }
        return mapped.joined(separator: " ")
    }

    private func insertSpaceBetweenLeadingDigitsAndLetters(in s: String) -> String {
        guard let first = s.first, first.isNumber else { return s }
        let digits = String(s.prefix { $0.isNumber })
        let rest = String(s.drop { $0.isNumber })
        if rest.first?.isLetter == true { return digits + " " + rest }
        return s
    }
}
