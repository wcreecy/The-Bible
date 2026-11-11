import SwiftUI

enum GameLobbyPreviewKind {
    case quiz
    case hangman
    case beatTheClock
    case quizReverse
    case bookOrder
    case wordSearch
    case scramble
    case crossword
    case whoAmI
    case wordle
    case trivia
}

struct GameLobbyPreview: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let kind: GameLobbyPreviewKind
    var bookOrderBooks: [String] = ["Genesis", "Exodus", "Leviticus"]

    var body: some View {
        if horizontalSizeClass == .regular {
            GroupBox("Game Preview") {
                preview
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 180)
            }
            .padding(.horizontal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch kind {
        case .quiz:
            HStack(spacing: 24) {
                previewPrompt(icon: "text.quote", title: "For God so loved the world…", subtitle: "Which book is this from?")
                VStack(spacing: 8) {
                    previewChoice("Matthew")
                    previewChoice("John", selected: true)
                    previewChoice("Romans")
                }
            }
        case .hangman:
            HStack(spacing: 36) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(.teal)
                VStack(spacing: 18) {
                    Text("_  _  _  _  _")
                        .font(.title.weight(.bold).monospaced())
                    Text("A   E   I   O   U")
                        .font(.headline.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        case .beatTheClock:
            HStack(spacing: 30) {
                ZStack {
                    Circle().stroke(Color.indigo.opacity(0.18), lineWidth: 12)
                    Circle().trim(from: 0, to: 0.68).stroke(Color.indigo, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("15").font(.title.bold().monospacedDigit())
                }
                .frame(width: 96, height: 96)
                previewPrompt(icon: "person.fill", title: "Moses", subtitle: "Name a book that mentions this person")
            }
        case .quizReverse:
            HStack(spacing: 24) {
                previewPrompt(icon: "bookmark.fill", title: "Psalm 23:1", subtitle: "Choose the matching verse")
                VStack(spacing: 8) {
                    previewChoice("The Lord is my shepherd…", selected: true)
                    previewChoice("In the beginning…")
                    previewChoice("Rejoice evermore.")
                }
            }
        case .bookOrder:
            VStack(spacing: 7) {
                ForEach(Array(bookOrderBooks.prefix(3).enumerated()), id: \.offset) { index, bookName in
                    previewOrderRow("\(index + 1)", bookName)
                }
            }
            .frame(maxWidth: 400)
        case .wordSearch:
            VStack(spacing: 4) {
                ForEach(["F A I T H", "G R A C E", "P E A C E", "L O V E S", "H O P E R"], id: \.self) { row in
                    Text(row)
                        .font(.headline.monospaced().weight(.semibold))
                        .foregroundStyle(row == "G R A C E" ? .green : .primary)
                        .padding(.horizontal, 10)
                        .background(row == "G R A C E" ? Color.green.opacity(0.14) : .clear, in: Capsule())
                }
            }
        case .scramble:
            HStack(spacing: 24) {
                previewPrompt(icon: "text.line.first.and.arrowtriangle.forward", title: "H E S O J P", subtitle: "Unscramble the Bible word")
                Text("JOSEPH")
                    .font(.title2.weight(.bold).monospaced())
                    .foregroundStyle(.pink)
            }
        case .crossword:
            HStack(spacing: 24) {
                VStack(spacing: 3) {
                    ForEach(["N O A H #", "# A # A #", "# R U T H", "# K # A #"], id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(Array(row.split(separator: " ").enumerated()), id: \.offset) { _, letter in
                                Text(letter == "#" ? "" : String(letter))
                                    .font(.subheadline.weight(.bold).monospaced())
                                    .frame(width: 24, height: 24)
                                    .background(letter == "#" ? Color.primary.opacity(0.8) : Color(.systemBackground))
                                    .border(Color.primary.opacity(0.3), width: 0.5)
                            }
                        }
                    }
                }
                previewPrompt(icon: CrosswordGameView.systemImage, title: "1 Across", subtitle: "Built an ark before the flood")
            }
        case .whoAmI:
            HStack(spacing: 24) {
                previewPrompt(icon: "person.crop.circle.fill", title: "Who?", subtitle: "I built an ark before the flood.")
                VStack(spacing: 8) {
                    previewChoice("Abraham")
                    previewChoice("Noah", selected: true)
                    previewChoice("Moses")
                }
            }
        case .wordle:
            VStack(spacing: 6) {
                wordleRow(["G", "R", "A", "C", "E"], colors: [.green, .secondary, .yellow, .secondary, .green])
                wordleRow(["F", "A", "I", "T", "H"], colors: Array(repeating: .secondary, count: 5))
                wordleRow(["", "", "", "", ""], colors: Array(repeating: .secondary, count: 5))
            }
        case .trivia:
            HStack(spacing: 24) {
                previewPrompt(icon: "questionmark.text.page.fill", title: "Who built the ark?", subtitle: "Choose the correct answer")
                VStack(spacing: 8) {
                    previewChoice("Abraham")
                    previewChoice("Noah", selected: true)
                    previewChoice("Moses")
                }
            }
        }
    }

    private func previewPrompt(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.tint)
            Text(title).font(.headline).multilineTextAlignment(.center)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: 310)
    }

    private func previewChoice(_ title: String, selected: Bool = false) -> some View {
        HStack {
            Text(title).lineLimit(1)
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        }
        .font(.subheadline.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? Color.accentColor : Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 330)
    }

    private func previewOrderRow(_ number: String, _ title: String) -> some View {
        HStack {
            Text(number).font(.caption.bold()).foregroundStyle(.secondary).frame(width: 24)
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func wordleRow(_ letters: [String], colors: [Color]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                Text(letter)
                    .font(.headline.bold())
                    .foregroundStyle(letter.isEmpty ? Color.primary : .white)
                    .frame(width: 38, height: 38)
                    .background(letter.isEmpty ? Color.clear : colors[index], in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.35)))
            }
        }
    }
}
