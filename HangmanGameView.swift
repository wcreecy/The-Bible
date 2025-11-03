import SwiftUI

struct HangmanGameView: View {
    enum Theme: String, CaseIterable, Identifiable {
        case all = "All"
        case people = "People"
        case places = "Places"
        case books = "Books"
        var id: String { rawValue }
    }

    @State private var started = false
    @State private var theme: Theme = .all

    @State private var targetWord: String = ""
    @State private var displayWord: String = ""

    @State private var guessedLetters: Set<Character> = []
    @State private var wrongGuesses: Int = 0
    @State private var maxWrong: Int = 7

    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var roundOver: Bool = false
    @State private var didWin: Bool = false

    @State private var loadedPeople: [BibleName] = []
    @State private var loadedPlaces: [BibleLocation] = []

    @State private var navigateToReader: Bool = false
    @State private var navBook: Book? = nil
    @State private var navChapter: Chapter? = nil
    @State private var navStartVerse: Int = 1

    @State private var currentRoundCategory: Theme = .books

    private let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 32)
                    Text("Bible Hangman")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Text("Guess the hidden word from a verse. Use the hint to help!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Picker("Theme", selection: $theme) {
                        ForEach(Theme.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button("Start") { startGame() }
                        .buttonStyle(.borderedProminent)
                        .font(.title2)
                        .frame(maxWidth: 240)
                    Spacer(minLength: 32)
                } else {
                    HStack {
                        Label("Category: \(currentRoundCategory.rawValue)", systemImage: "tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    // Stats
                    HStack(spacing: 12) {
                        statPill(title: "Correct", value: "\(score)", tint: .blue)
                        statPill(title: "Total", value: "\(answered)", tint: .orange)
                        statPill(title: "Percent", value: percentString(correct: score, answered: answered), tint: .purple)
                    }

                    // Word Display
                    Text(spacedDisplayWord())
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .padding(.top, 8)
                        .accessibilityLabel("Word to guess")

                    // Lives
                    Text("Mistakes: \(wrongGuesses)/\(maxWrong)")
                        .font(.subheadline)
                        .foregroundStyle(wrongGuesses >= maxWrong - 1 ? .red : .secondary)

                    // Keyboard
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                        ForEach(alphabet, id: \.self) { ch in
                            Button(action: { guess(ch) }) {
                                Text(String(ch))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .disabled(guessedLetters.contains(ch) || roundOver)
                        }
                    }
                    .padding(.top, 6)

                    if roundOver {
                        Text(didWin ? "You got it!" : "Out of guesses: \(targetWord.uppercased())")
                            .font(.headline)
                            .foregroundStyle(didWin ? .green : .red)
                            .padding(.top, 8)

                        if let ref = firstReferenceForCurrentTarget() {
                            Button {
                                openFirstReference(ref)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "book")
                                    Text(ref)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .padding(.top, 2)
                        }

                        Button("Next") { nextRound() }
                            .buttonStyle(.borderedProminent)
                            .font(.title2)
                            .padding(.top, 4)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Hangman")
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
    }

    private func startGame() {
        if loadedPeople.isEmpty || loadedPlaces.isEmpty {
            Task {
                if loadedPeople.isEmpty { loadedPeople = await GameDataLoaders.loadNamesAsync() }
                if loadedPlaces.isEmpty { loadedPlaces = await GameDataLoaders.loadLocationsAsync() }
                score = 0
                answered = 0
                started = true
                nextRound()
            }
            return
        }
        score = 0
        answered = 0
        started = true
        nextRound()
    }

    private func nextRound(resetScore: Bool = false) {
        guessedLetters = []
        wrongGuesses = 0
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

        let upperTarget = targetWord.uppercased()
        if upperTarget.contains(upper) {
            // Reveal letters
            var chars = Array(displayWord)
            for (i, t) in upperTarget.enumerated() {
                if t == upper {
                    // Preserve original case but display uppercase
                    let originalChar = targetWord[targetWord.index(targetWord.startIndex, offsetBy: i)]
                    chars[i] = Character(String(originalChar).uppercased())
                }
            }
            displayWord = String(chars)
            checkWin()
        } else {
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
        answered += 1
        if win { score += 1 }
    }

    private func generateRound() {
        // Determine actual category for this round
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
        case .places:
            if loadedPlaces.isEmpty { loadedPlaces = GameDataLoaders.loadLocations() }
            guard !loadedPlaces.isEmpty else { return }
            // Try multiple times to get a valid, non-empty location
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

    private func firstReferenceForCurrentTarget() -> String? {
        switch currentRoundCategory {
        case .people:
            return loadedPeople.first { $0.name.caseInsensitiveCompare(targetWord) == .orderedSame }?.firstReference
        case .places:
            return loadedPlaces.first { $0.location.caseInsensitiveCompare(targetWord) == .orderedSame }?.firstReference
        case .books:
            return nil
        case .all:
            return nil
        }
    }

    private func openFirstReference(_ ref: String) {
        // Expect formats like "Genesis 1:1" or "1 Samuel 3:4"; tolerate abbreviations and punctuation like "1kgs 10:15", "act 6:5", "John 3:16–18", or trailing commas/periods
        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split { $0.isWhitespace }
        guard let lastPart = parts.last else { return }
        // Clean the last token: remove common trailing punctuation and normalize en dashes to hyphens
        var last = String(lastPart)
        last = last.replacingOccurrences(of: "\u{2013}", with: "-") // en dash
        last = last.replacingOccurrences(of: "\u{2014}", with: "-") // em dash
        last = last.trimmingCharacters(in: CharacterSet(charactersIn: ",;.)]”’\""))
        // Extract chapter and verse from the last token
        guard let colonIndex = last.firstIndex(of: ":") else { return }
        let chapterSlice = last[..<colonIndex]
        let verseSlice = last[last.index(after: colonIndex)...]
        // Take only leading digits for chapter and verse (ignore ranges like 16-18 or suffixes like 16a)
        let chapterDigits = chapterSlice.prefix { $0.isNumber }
        let verseDigits = verseSlice.prefix { $0.isNumber }
        guard let chapterNum = Int(chapterDigits), let verseNum = Int(verseDigits) else { return }
        // Book name is everything before the last token
        let bookRaw = parts.dropLast().joined(separator: " ")
        guard let book = resolveBook(named: bookRaw) else { return }
        guard let chapter = book.chapters.first(where: { $0.number == chapterNum }) else { return }
        navBook = book
        navChapter = chapter
        navStartVerse = verseNum
        navigateToReader = true
    }

    private func resolveBook(named raw: String) -> Book? {
        // Try direct match first
        if let direct = BibleData.books.first(where: { $0.name.caseInsensitiveCompare(raw) == .orderedSame }) {
            return direct
        }
        // Try inserting space between leading digits and letters (e.g., "1Samuel" -> "1 Samuel", "1kgs" -> "1 kgs")
        let spaced = insertSpaceBetweenLeadingDigitsAndLetters(in: raw)
        let normalized = normalizeBookName(spaced)
        if let match = BibleData.books.first(where: { $0.name.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match
        }
        // Try relaxed comparison: remove spaces and compare
        let collapsed = normalized.replacingOccurrences(of: " ", with: "")
        if let match = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match
        }
        return nil
    }

    private func normalizeBookName(_ s: String) -> String {
        // Lowercase tokens, expand common abbreviations, then title-case appropriately
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
        // Tokenize by whitespace and punctuation
        let cleaned = s.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        var tokens = cleaned.split{ $0.isWhitespace }.map { String($0) }
        // If first token is a number stuck to letters (e.g., "1kgs"), separate
        if let first = tokens.first, first.first?.isNumber == true, first.drop(while: { $0.isNumber }).first?.isLetter == true {
            let digits = String(first.prefix { $0.isNumber })
            let rest = String(first.drop { $0.isNumber })
            tokens[0] = digits
            if rest.isEmpty == false { tokens.insert(rest, at: 1) }
        }
        // Map abbreviations
        let mapped = tokens.enumerated().map { (idx, t) -> String in
            let lower = t.lowercased()
            if let exp = abbrev[lower] { return exp }
            // Title-case otherwise, but keep numeric ordinals as-is
            if Int(lower) != nil { return t }
            return t.prefix(1).uppercased() + t.dropFirst().lowercased()
        }
        // Special handling: if sequence like ["1", "Kings"] or ["2", "Samuel"], join with space
        return mapped.joined(separator: " ")
    }

    private func insertSpaceBetweenLeadingDigitsAndLetters(in s: String) -> String {
        guard let first = s.first, first.isNumber else { return s }
        // Insert a space after the leading digit sequence if next is a letter
        let digits = String(s.prefix { $0.isNumber })
        let rest = String(s.drop { $0.isNumber })
        if rest.first?.isLetter == true { return digits + " " + rest }
        return s
    }
}

#Preview {
    NavigationStack { HangmanGameView() }
}
