import SwiftUI

struct QuizView: View {
    @AppStorage("quizScope") private var quizScopeRaw: String = "whole"
    @AppStorage("quizAllTimeCorrect") private var allTimeCorrect: Int = 0
    @AppStorage("quizAllTimeAnswered") private var allTimeAnswered: Int = 0
    @AppStorage("quizAllTimeBestStreak") private var allTimeBestStreak: Int = 0
    
    struct VerseRef {
        let bookName: String
        let text: String
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
    @State private var history: [QuizQuestion] = []
    @State private var currentIndex: Int = -1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 48)
                    Text("Bible Quiz")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .multilineTextAlignment(.center)
                    
                    Text("Test your knowledge by guessing the book of the Bible from a given verse.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button("Start") {
                        startQuiz()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.title2)
                    .frame(maxWidth: 240)
                    Spacer(minLength: 48)
                } else {
                    VStack(spacing: 16) {
                        // Top card with title and streak badges
                        VStack {
                            VStack(alignment: .leading, spacing: 12) {
                                // Current session stats
                                HStack(spacing: 12) {
                                    Text("Current")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 70, alignment: .leading)
                                    statPill(title: "Correct", value: "\(score)", tint: .blue)
                                    statPill(title: "Answered", value: "\(sessionAnswered)", tint: .orange)
                                    statPill(title: "Streak", value: "\(currentStreak)", tint: .green)
                                }
                                // All-time stats
                                HStack(spacing: 12) {
                                    Text("All-time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 70, alignment: .leading)
                                    statPill(title: "Correct", value: "\(allTimeCorrect)", tint: .blue)
                                    statPill(title: "Answered", value: "\(allTimeAnswered)", tint: .orange)
                                    statPill(title: "Streak", value: "\(allTimeBestStreak)", tint: .green)
                                }
                            }
                            .padding()
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        
                        // Verse card
                        VStack {
                            Text("“\(currentVerseText)”")
                                .italic()
                                .font(.title3)
                                .multilineTextAlignment(.center)
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
                            Text("Correct answer: \(correctBook) \(currentChapterNumber):\(currentVerseNumber)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Bible Quiz")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if started && currentIndex > 0 {
                    Button("Previous") { showPrevious() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if started && selectedOption != nil {
                    Button("Next Question") { showNext() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
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
        
        let verseText = randomVerse.text
        let bookName = randomBook.name
        let chapterNum = randomChapter.number
        let verseNum = randomVerse.number

        var wrongBooks = filteredBooks
            .map { $0.name }
            .filter { $0 != bookName }
            .shuffled()
        if wrongBooks.count > 3 { wrongBooks = Array(wrongBooks.prefix(3)) }
        let opts = (wrongBooks + [bookName]).shuffled()

        let q = QuizQuestion(
            verseText: verseText,
            correctBook: bookName,
            chapter: chapterNum,
            verse: verseNum,
            options: opts,
            selected: nil
        )
        history.append(q)
        currentIndex = history.count - 1
        loadQuestion(from: q)
    }
    
    private func selectOption(_ name: String) {
        guard selectedOption == nil else { return }
        // Only allow answering on the latest question
        guard currentIndex >= 0 && currentIndex == history.count - 1 else { return }
        selectedOption = name
        history[currentIndex].selected = name
        sessionAnswered += 1
        allTimeAnswered += 1
        if name == correctBook {
            score += 1
            allTimeCorrect += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            allTimeBestStreak = max(allTimeBestStreak, currentStreak)
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
        loadQuestion(from: q)
    }

    private func showNext() {
        if currentIndex < history.count - 1 {
            currentIndex += 1
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
    
    private func borderColor(for option: String) -> Color {
        guard let selected = selectedOption else { return .clear }
        if option == correctBook {
            return .green
        }
        return .clear
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
    
    private func labelForOption(_ option: String) -> String {
        if showAnswerReveal && option == correctBook {
            return "\(correctBook) \(currentChapterNumber):\(currentVerseNumber)"
        }
        return option
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
}

