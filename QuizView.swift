import SwiftUI
import Combine
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    
    @AppStorage("quizScope") private var quizScopeRaw: String = "whole"
    @AppStorage("quizDifficulty") private var quizDifficulty: String = "easy"
    
    @AppStorage("quizAllTimeCorrect_easy") private var allTimeCorrectEasy: Int = 0
    @AppStorage("quizAllTimeAnswered_easy") private var allTimeAnsweredEasy: Int = 0
    @AppStorage("quizAllTimeBestStreak_easy") private var allTimeBestStreakEasy: Int = 0

    @AppStorage("quizAllTimeCorrect_normal") private var allTimeCorrectNormal: Int = 0
    @AppStorage("quizAllTimeAnswered_normal") private var allTimeAnsweredNormal: Int = 0
    @AppStorage("quizAllTimeBestStreak_normal") private var allTimeBestStreakNormal: Int = 0

    @AppStorage("quizAllTimeCorrect_hard") private var allTimeCorrectHard: Int = 0
    @AppStorage("quizAllTimeAnswered_hard") private var allTimeAnsweredHard: Int = 0
    @AppStorage("quizAllTimeBestStreak_hard") private var allTimeBestStreakHard: Int = 0

    private var allTimeCorrect: Int {
        switch quizDifficulty {
        case "normal": return allTimeCorrectNormal
        case "hard": return allTimeCorrectHard
        default: return allTimeCorrectEasy
        }
    }

    private var allTimeAnswered: Int {
        switch quizDifficulty {
        case "normal": return allTimeAnsweredNormal
        case "hard": return allTimeAnsweredHard
        default: return allTimeAnsweredEasy
        }
    }

    private var allTimeBestStreak: Int {
        switch quizDifficulty {
        case "normal": return allTimeBestStreakNormal
        case "hard": return allTimeBestStreakHard
        default: return allTimeBestStreakEasy
        }
    }
    
    private func incrementAllTimeAnswered() {
        switch quizDifficulty {
        case "normal": allTimeAnsweredNormal += 1
        case "hard": allTimeAnsweredHard += 1
        default: allTimeAnsweredEasy += 1
        }
    }
    
    private func incrementAllTimeCorrect() {
        switch quizDifficulty {
        case "normal": allTimeCorrectNormal += 1
        case "hard": allTimeCorrectHard += 1
        default: allTimeCorrectEasy += 1
        }
    }
    
    private func updateAllTimeBestStreak(_ newStreak: Int) {
        switch quizDifficulty {
        case "normal": allTimeBestStreakNormal = max(allTimeBestStreakNormal, newStreak)
        case "hard": allTimeBestStreakHard = max(allTimeBestStreakHard, newStreak)
        default: allTimeBestStreakEasy = max(allTimeBestStreakEasy, newStreak)
        }
    }
    
    private struct QuizQuestion: Identifiable {
        let id = UUID()
        let verseText: String
        let correctBook: String
        let chapter: Int
        let verse: Int
        let options: [String]
        var selected: String?
    }

    private var isViewingPrevious: Bool {
        currentIndex >= 0 && currentIndex < history.count - 1
    }
    
    @State private var started = false
    @State private var currentVerseText = ""
    @State private var correctBook = ""
    @State private var options: [String] = []
    @State private var selectedOption: String? = nil
    @State private var score = 0
    @State private var questionNumber = 0
    @State private var sessionAnswered = 0
    @State private var currentChapterNumber: Int = 0
    @State private var currentVerseNumber: Int = 0
    
    @State private var currentStreak: Int = 0
    @State private var bestStreak: Int = 0
    @State private var showAnswerReveal: Bool = false
    @State private var remainingSeconds: Int = 0
    @State private var quizTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var wasInRedZone: Bool = false
    @State private var pulseOn: Bool = false
    @State private var history: [QuizQuestion] = []
    @State private var currentIndex: Int = -1
    
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false
    
    private var isPreviousEnabled: Bool {
        started && currentIndex > 0 && !(selectedOption == nil && (quizDifficulty == "normal" || quizDifficulty == "hard") && remainingSeconds > 0)
    }

    private var isNextEnabled: Bool {
        started && (selectedOption != nil || currentIndex < history.count - 1)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    
                    Text("Test your knowledge by guessing the book of the Bible from a given verse.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Pick a verse source and difficulty, then tap Start.")
                                    Text("• Read the verse, then choose the correct book from the options.")
                                    Text("• In timed modes, answer before the clock runs out.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Easy: No timer; options from the whole scope.")
                                    Text("• Medium: 30 seconds per question.")
                                    Text("• Hard: 20 seconds; wrong options are from the same testament to increase challenge.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Levels").font(.headline)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .center, spacing: 12) {
                        VStack(spacing: 6) {
                            Text("Verse Source")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Verse Source", selection: Binding<String>(get: { quizScopeRaw }, set: { quizScopeRaw = $0 })) {
                                Text("OT/NT").tag("whole")
                                Text("OT").tag("old")
                                Text("NT").tag("new")
                            }
                            .pickerStyle(.segmented)
                        }
                        VStack(spacing: 6) {
                            Text("Difficulty")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Difficulty", selection: Binding<String>(get: { quizDifficulty }, set: { quizDifficulty = $0 })) {
                                Text("Easy").tag("easy")
                                Text("Medium").tag("normal")
                                Text("Hard").tag("hard")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.horizontal)
                    
                    Button("Start") {
                        startQuiz()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
                    .frame(maxWidth: 240)
                    Spacer(minLength: 48)
                } else {
                    VStack(spacing: 16) {
                        // Shared scoreboard
                        GameScoreboardCard(
                            currentCorrect: score,
                            currentAnswered: sessionAnswered,
                            currentStreak: currentStreak,
                            allTimeCorrect: allTimeCorrect,
                            allTimeAnswered: allTimeAnswered,
                            allTimeBestStreak: allTimeBestStreak
                        )

                        // Verse card
                        VStack {
                            Text("“\(currentVerseText)”")
                                .italic()
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .lineLimit(6)
                                .truncationMode(.tail)
                                .foregroundColor(.primary)
                                .padding(24)
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.systemBackground)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        if (quizDifficulty == "normal" || quizDifficulty == "hard") && selectedOption == nil {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                Text("Time left: \(remainingSeconds)s")
                                    .monospacedDigit()
                            }
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(timerColor(for: remainingSeconds))
                            .scaleEffect(pulseOn ? 1.12 : 1.0)
                            .animation(.easeInOut(duration: 0.25), value: pulseOn)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                        
                        Text("Which book is this from?")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(options, id: \.self) { option in
                                Button {
                                    selectOption(option)
                                } label: {
                                    Text(labelForOption(option))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .foregroundColor(buttonForeground(for: option))
                                }
                                .disabled(selectedOption != nil || isViewingPrevious)
                                .background(buttonBackground(for: option))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            selectedOption != nil && option == correctBook ? Color.green : Color.black.opacity(0.15),
                                            lineWidth: selectedOption != nil && option == correctBook ? 3 : 1
                                        )
                                )
                                .cornerRadius(12)
                                .font(.body)
                            }
                        }
                        .padding(.horizontal)
                        
                        if showAnswerReveal {
                            HStack(spacing: 8) {
                                Text("Correct answer: \(correctBook) \(currentChapterNumber):\(currentVerseNumber)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Button(action: { toggleFavoriteCurrent() }) {
                                    Image(systemName: isCurrentFavorited() ? "heart.fill" : "heart")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isCurrentFavorited() ? "Remove Favorite" : "Add to Favorites")
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding(.horizontal)
        }
        .onReceive(quizTimer) { _ in
            guard started else { return }
            guard selectedOption == nil else { return }
            guard quizDifficulty == "normal" || quizDifficulty == "hard" else { return }
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                timeOutQuestion()
            }
        }
        .onChange(of: remainingSeconds) { _, newValue in
            guard started, selectedOption == nil, (quizDifficulty == "normal" || quizDifficulty == "hard") else { return }
            let inRed = isInRedZone(newValue)
            if inRed && !wasInRedZone {
                startTimerPulse()
            }
            wasInRedZone = inRed
        }
        .navigationTitle("Bible Quiz")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Previous") { showPrevious() }
                    .buttonStyle(ToolbarPillButtonStyle(tint: .accentColor))
                    .controlSize(.regular)
                    .disabled(!isPreviousEnabled)

                Button("Next") { showNext() }
                    .buttonStyle(ToolbarPillButtonStyle(tint: .accentColor))
                    .controlSize(.regular)
                    .disabled(!isNextEnabled)
            }
        }
        .onDisappear { resetSessionScores() }
    }
    
    private func startQuiz() {
        currentStreak = 0
        // bestStreak is kept as is
        started = true
        score = 0
        questionNumber = 0
        sessionAnswered = 0
        history = []
        currentIndex = -1
        generateQuestion()
    }
    
    private func generateQuestion() {
        selectedOption = nil
        showAnswerReveal = false
        
        // Define Old Testament books set
        let oldTestamentSet: Set<String> = [
            "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
            "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
            "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
            "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
            "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
            "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
            "Zephaniah", "Haggai", "Zechariah", "Malachi"
        ]
        
        // Define New Testament books set
        let newTestamentSet: Set<String> = [
            "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
            "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
            "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
            "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
            "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
            "Jude", "Revelation"
        ]
        
        var filteredBooks: [Book] = []
        
        switch quizScopeRaw {
        case "old":
            filteredBooks = BibleData.books.filter { oldTestamentSet.contains($0.name) }
        case "new":
            filteredBooks = BibleData.books.filter { newTestamentSet.contains($0.name) }
        default:
            filteredBooks = BibleData.books
        }
        
        guard !filteredBooks.isEmpty else {
            currentVerseText = "No verse found."
            correctBook = ""
            options = []
            return
        }
        
        guard let randomBook = filteredBooks.randomElement(),
              let randomChapter = randomBook.chapters.randomElement(),
              let randomVerse = randomChapter.verses.randomElement() else {
            currentVerseText = "No verse found."
            correctBook = ""
            options = []
            return
        }
        
        // Set timer duration based on difficulty
        switch quizDifficulty {
        case "normal":
            remainingSeconds = 30
        case "hard":
            remainingSeconds = 20
        default:
            remainingSeconds = 0
        }
        
        wasInRedZone = false
        pulseOn = false
        
        let verseText = randomVerse.text
        let bookName = randomBook.name
        let chapterNum = randomChapter.number
        let verseNum = randomVerse.number

        // Build wrong options pool
        let allBookNames = filteredBooks.map { $0.name }
        let correctName = bookName

        // Determine testament of the correct book
        let isOldTestament = oldTestamentSet.contains(correctName)

        var wrongPool = allBookNames.filter { $0 != correctName }
        if quizDifficulty == "hard" {
            wrongPool = wrongPool.filter { isOldTestament == oldTestamentSet.contains($0) }
        }
        var wrongBooks = wrongPool.shuffled()
        if wrongBooks.count > 3 { wrongBooks = Array(wrongBooks.prefix(3)) }
        let opts = (wrongBooks + [correctName]).shuffled()

        let q = QuizQuestion(
            verseText: verseText,
            correctBook: bookName,
            chapter: chapterNum,
            verse: verseNum,
            options: opts,
            selected: nil
        )
        var newHistory = history
        newHistory.append(q)
        history = newHistory
        currentIndex = history.count - 1
        loadQuestion(from: q)
    }
    
    private func selectOption(_ name: String) {
        guard selectedOption == nil else { return }
        // Only allow answering on the latest question
        guard currentIndex >= 0 && currentIndex == history.count - 1 else { return }
        pulseOn = false
        remainingSeconds = 0
        selectedOption = name
        var newHistory = history
        newHistory[currentIndex].selected = name
        history = newHistory
        sessionAnswered += 1
        incrementAllTimeAnswered()
        if name == correctBook {
            score += 1
            incrementAllTimeCorrect()
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            updateAllTimeBestStreak(currentStreak)
        } else {
            currentStreak = 0
        }
        showAnswerReveal = true
    }
    
    private func nextQuestion() {
        questionNumber += 1
        generateQuestion()
    }
    
    private func showPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        let q = history[currentIndex]
        remainingSeconds = 0
        loadQuestion(from: q)
    }

    private func showNext() {
        if currentIndex < history.count - 1 {
            currentIndex += 1
            remainingSeconds = 0
            loadQuestion(from: history[currentIndex])
        } else {
            nextQuestion()
        }
    }
    
    private func loadQuestion(from q: QuizQuestion) {
        currentVerseText = q.verseText
        correctBook = q.correctBook
        currentChapterNumber = q.chapter
        currentVerseNumber = q.verse
        options = q.options
        selectedOption = q.selected
        showAnswerReveal = q.selected != nil
    }
    
    private func resetSessionScores() {
        score = 0
        sessionAnswered = 0
        currentStreak = 0
        bestStreak = 0
    }
    
    private func buttonBackground(for option: String) -> Color {
        guard let selected = selectedOption else {
            return Color.clear
        }
        if selected == option {
            return option == correctBook ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
        }
        return Color.clear
    }
    
    private func buttonForeground(for option: String) -> Color {
        guard let selected = selectedOption else {
            return .primary
        }
        if selected == option {
            return .primary
        }
        return .primary
    }
    
    private func labelForOption(_ option: String) -> String {
        if showAnswerReveal && option == correctBook {
            return "\(correctBook) \(currentChapterNumber):\(currentVerseNumber)"
        }
        return option
    }

    private func timerColor(for seconds: Int) -> Color {
        switch quizDifficulty {
        case "normal":
            if seconds > 10 { return .green }
            else if seconds >= 5 { return .yellow } // 5...10 inclusive
            else { return .red } // <5
        case "hard":
            if seconds > 8 { return .green }
            else if seconds >= 4 { return .yellow } // 4...8 inclusive
            else { return .red } // <4
        default:
            return .secondary
        }
    }

    private func isInRedZone(_ seconds: Int) -> Bool {
        switch quizDifficulty {
        case "normal":
            return seconds < 5
        case "hard":
            return seconds < 4
        default:
            return false
        }
    }

    private func startTimerPulse() {
        // Perform a brief pulse sequence when entering red zone
        let pulses = 3
        for i in 0..<(pulses * 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    pulseOn.toggle()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pulses * 2) * 0.25 + 0.01) {
            pulseOn = false
        }
    }

    private func timeOutQuestion() {
        // Mark as answered incorrectly due to timeout
        guard selectedOption == nil else { return }
        selectedOption = "__timeout__" // disable buttons
        sessionAnswered += 1
        incrementAllTimeAnswered()
        currentStreak = 0
        showAnswerReveal = true
    }
    
    private func isCurrentFavorited() -> Bool {
        favorites.contains { fav in
            fav.bookName == correctBook && fav.chapterNumber == currentChapterNumber && fav.verseNumber == currentVerseNumber
        }
    }

    private func toggleFavoriteCurrent() {
        if let existing = favorites.first(where: { $0.bookName == correctBook && $0.chapterNumber == currentChapterNumber && $0.verseNumber == currentVerseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(
                bookName: correctBook,
                chapterNumber: currentChapterNumber,
                verseNumber: currentVerseNumber,
                verseText: currentVerseText
            )
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
}
