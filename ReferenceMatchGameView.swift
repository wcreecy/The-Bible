import SwiftUI

struct ReferenceMatchGameView: View {
    // Consistent modern button styles (matching Hangman)
    private struct GameProminentButtonStyle: ButtonStyle {
        var tint: Color = .accentColor
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint)
                        .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.12), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        }
    }

    private struct ModernPillButtonStyle: ButtonStyle {
        var tint: Color = .accentColor
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(tint)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    .ultraThinMaterial,
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(configuration.isPressed ? 0.6 : 0.35), lineWidth: configuration.isPressed ? 2 : 1)
                )
                .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.08), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
        }
    }

    enum Difficulty: String, CaseIterable, Identifiable { case easy, medium, hard; var id: String { rawValue } }
    @State private var difficulty: Difficulty = .medium

    @State private var started = false
    @State private var questionNumber: Int = 0
    @State private var score: Int = 0
    @State private var answered: Int = 0

    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0

    @State private var history: [(book: Book, chapter: Chapter, verse: Verse, options: [String], correct: String, selected: String?)] = []
    @State private var currentIndex: Int = -1

    private var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: "refmatchAllTimeCorrect_\(difficultyKeySuffix())") }
    private var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: "refmatchAllTimeAnswered_\(difficultyKeySuffix())") }
    private var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: "refmatchAllTimeBestStreak_\(difficultyKeySuffix())") }

    @State private var refBook: Book? = nil
    @State private var refChapter: Chapter? = nil
    @State private var refVerse: Verse? = nil

    @State private var options: [String] = []
    @State private var correctOption: String = ""
    @State private var selectedOption: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 32)
                    Text("Verse Match")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Text("Choose the verse text that matches the reference.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { d in
                            Text(d.rawValue.capitalized).tag(d)
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
                    VStack(alignment: .leading, spacing: 8) {
                        // Header labels
                        HStack {
                            Text("")
                                .frame(width: 80, alignment: .leading)
                            Text("Correct").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Total").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Streak").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Percent").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // Current session row
                        HStack {
                            Text("Current").font(.subheadline).frame(width: 80, alignment: .leading)
                            Text("\(score)").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(answered)").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(currentBestStreak)")
                                .foregroundStyle(currentStreak == currentBestStreak && currentBestStreak > 0 ? .green : .primary)
                                .animation(.easeInOut(duration: 0.2), value: currentBestStreak)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(percentString(correct: score, answered: answered)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // All-time row
                        HStack {
                            Text("All-time").font(.subheadline).frame(width: 80, alignment: .leading)
                            Text("\(allTimeCorrect)").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(allTimeAnswered)").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(allTimeBestStreak)").frame(maxWidth: .infinity, alignment: .leading)
                            Text(percentString(correct: allTimeCorrect, answered: allTimeAnswered)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Reference card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            if let b = refBook, let c = refChapter, let v = refVerse {
                                Text("Reference")
                                    .font(.headline)
                                Text("\(b.name) \(c.number):\(v.number)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            } else {
                                Text("No reference")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Which verse matches this reference?")
                        .font(.headline)
                        .padding(.top, 4)

                    VStack(spacing: 12) {
                        ForEach(options, id: \.self) { opt in
                            Button {
                                select(opt)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(opt)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding()
                                .background(buttonBackground(for: opt))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(buttonBorder(for: opt), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedOption != nil)
                        }
                    }

                    if let sel = selectedOption {
                        let correct = sel == correctOption
                        Text(correct ? "Correct!" : "Not quite.")
                            .font(.headline)
                            .foregroundStyle(correct ? .green : .red)
                            .padding(.top, 8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Verse Match")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if started && currentIndex > 0 {
                    Button("Previous") { currentIndex -= 1; loadFromHistory() }
                        .disabled(selectedOption == nil)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if started {
                    Button("Next") { 
                        if currentIndex < history.count - 1 { currentIndex += 1; loadFromHistory() }
                        else { nextQuestion() }
                    }
                    .disabled(selectedOption == nil)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.regular)
                }
            }
        }
    }

    private func startGame() {
        score = 0
        answered = 0
        currentStreak = 0
        currentBestStreak = 0
        questionNumber = 0
        started = true
        history = []
        currentIndex = -1
        generateQuestion()
    }

    private func nextQuestion() {
        questionNumber += 1
        selectedOption = nil
        generateQuestion()
    }

    private func select(_ opt: String) {
        guard selectedOption == nil else { return }
        selectedOption = opt
        if currentIndex >= 0 && currentIndex < history.count {
            history[currentIndex].selected = opt
        }
        answered += 1
        if opt == correctOption { score += 1 }

        if opt == correctOption {
            currentStreak += 1
            if currentStreak > currentBestStreak {
                currentBestStreak = currentStreak
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            updateAllTime(correct: 1, answered: 1, streak: currentBestStreak)
        } else {
            currentStreak = 0
            updateAllTime(correct: 0, answered: 1, streak: currentBestStreak)
        }
    }

    private func generateQuestion() {
        // Choose a random reference
        guard let book = BibleData.books.randomElement(),
              let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement() else {
            refBook = nil; refChapter = nil; refVerse = nil; options = []; correctOption = ""; return
        }
        refBook = book; refChapter = chapter; refVerse = verse
        let correct = verse.text
        correctOption = snippet(for: correct)

        // Build distractors: pick from other verses (avoid same reference text duplicate)
        var distractors: Set<String> = []
        var safety = 0
        while distractors.count < 3 && safety < 2000 {
            safety += 1
            guard let b = BibleData.books.randomElement(),
                  let c = b.chapters.randomElement(),
                  let v = c.verses.randomElement() else { continue }
            let snip = snippet(for: v.text)
            if snip != correctOption { distractors.insert(snip) }
        }
        var opts = Array(distractors)
        opts.append(correctOption)
        options = opts.shuffled()

        var newHistory = history
        newHistory.append((book: book, chapter: chapter, verse: verse, options: options, correct: correctOption, selected: nil))
        history = newHistory
        currentIndex = history.count - 1
        loadFromHistory()
    }

    private func loadFromHistory() {
        guard currentIndex >= 0 && currentIndex < history.count else { return }
        let h = history[currentIndex]
        refBook = h.book
        refChapter = h.chapter
        refVerse = h.verse
        options = h.options
        correctOption = h.correct
        selectedOption = h.selected
    }

    private func snippet(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 160 { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: 160)
        return String(trimmed[..<idx]) + "…"
    }

    private func buttonBackground(for opt: String) -> Color {
        guard let sel = selectedOption else { return Color(.secondarySystemBackground) }
        if opt == correctOption {
            return sel == opt ? Color.green.opacity(0.25) : Color.green.opacity(0.15)
        } else if sel == opt {
            return Color.red.opacity(0.25)
        }
        return Color(.secondarySystemBackground)
    }

    private func buttonBorder(for opt: String) -> Color {
        guard let sel = selectedOption else { return Color.black.opacity(0.12) }
        if opt == correctOption { return .green }
        if opt == sel { return .red }
        return Color.black.opacity(0.12)
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

    private func updateAllTime(correct addCorrect: Int, answered addAnswered: Int, streak: Int) {
        let defaults = UserDefaults.standard
        let suffix = difficultyKeySuffix()
        let correctKey = "refmatchAllTimeCorrect_\(suffix)"
        let answeredKey = "refmatchAllTimeAnswered_\(suffix)"
        let bestKey = "refmatchAllTimeBestStreak_\(suffix)"
        let newCorrect = defaults.integer(forKey: correctKey) + addCorrect
        let newAnswered = defaults.integer(forKey: answeredKey) + addAnswered
        let newBest = max(defaults.integer(forKey: bestKey), streak)
        defaults.set(newCorrect, forKey: correctKey)
        defaults.set(newAnswered, forKey: answeredKey)
        defaults.set(newBest, forKey: bestKey)
    }

    private func difficultyKeySuffix() -> String {
        switch difficulty { case .easy: return "easy"; case .medium: return "medium"; case .hard: return "hard" }
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "0%" }
        let pct = Int(round((Double(correct) / Double(answered)) * 100.0))
        return "\(pct)%"
    }
}

#Preview {
    NavigationStack { ReferenceMatchGameView() }
}
