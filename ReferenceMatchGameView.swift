import SwiftUI

struct ReferenceMatchGameView: View {
    @State private var started = false
    @State private var questionNumber: Int = 0
    @State private var score: Int = 0
    @State private var answered: Int = 0

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
                    Text("Reference Match")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Text("Choose the verse text that matches the reference.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
        .navigationTitle("Reference Match")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if started {
                    Button("Next") { nextQuestion() }
                        .disabled(selectedOption == nil)
                }
            }
        }
    }

    private func startGame() {
        score = 0
        answered = 0
        questionNumber = 0
        started = true
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
        answered += 1
        if opt == correctOption { score += 1 }
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

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "0%" }
        let pct = Int(round((Double(correct) / Double(answered)) * 100.0))
        return "\(pct)%"
    }
}

#Preview {
    NavigationStack { ReferenceMatchGameView() }
}
