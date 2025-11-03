import SwiftUI

struct HangmanGameView: View {
    enum Theme: String, CaseIterable, Identifiable {
        case all = "All"
        case parables = "Parables"
        case miracles = "Miracles"
        case psalms = "Psalms"
        var id: String { rawValue }
    }

    @State private var started = false
    @State private var theme: Theme = .all

    @State private var targetWord: String = ""
    @State private var displayWord: String = ""
    @State private var hintBook: String = ""
    @State private var hintChapter: Int = 0
    @State private var hintSnippet: String = ""

    @State private var guessedLetters: Set<Character> = []
    @State private var wrongGuesses: Int = 0
    @State private var maxWrong: Int = 7

    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var roundOver: Bool = false
    @State private var didWin: Bool = false

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
                    // Stats
                    HStack(spacing: 12) {
                        statPill(title: "Correct", value: "\(score)", tint: .blue)
                        statPill(title: "Total", value: "\(answered)", tint: .orange)
                        statPill(title: "Percent", value: percentString(correct: score, answered: answered), tint: .purple)
                    }

                    // Hint Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hint")
                            .font(.headline)
                        Text("\(hintBook) \(hintChapter)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\"\(hintSnippet)\"")
                            .italic()
                            .font(.body)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

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
    }

    private func startGame() {
        score = 0
        answered = 0
        started = true
        nextRound(resetScore: true)
    }

    private func nextRound(resetScore: Bool = false) {
        if resetScore {
            score = 0
            answered = 0
        }
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
        let books = filteredBooks(for: theme)
        guard let (book, chapter, verse) = randomReference(from: books) else { return }

        // Pick target word from verse text: alphabetic, length >= 4
        let words = verse.text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 }
        guard let chosen = words.randomElement() else {
            // If verse doesn't have suitable word, try again
            generateRound()
            return
        }

        targetWord = chosen
        displayWord = String(repeating: "_", count: chosen.count)
        hintBook = book.name
        hintChapter = chapter.number
        hintSnippet = String(verse.text.prefix(140))
    }

    private func filteredBooks(for theme: Theme) -> [Book] {
        switch theme {
        case .all:
            return BibleData.books
        case .psalms:
            return BibleData.books.filter { $0.name == "Psalms" }
        case .parables:
            // Approximate: use Gospels as parables-rich sources
            return BibleData.books.filter { ["Matthew","Mark","Luke","John"].contains($0.name) }
        case .miracles:
            // Approximate: Gospels + Acts
            return BibleData.books.filter { ["Matthew","Mark","Luke","John","Acts"].contains($0.name) }
        }
    }

    private func randomReference(from books: [Book]) -> (Book, Chapter, Verse)? {
        guard let book = books.randomElement(),
              let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement() else { return nil }
        return (book, chapter, verse)
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
}

#Preview {
    NavigationStack { HangmanGameView() }
}
