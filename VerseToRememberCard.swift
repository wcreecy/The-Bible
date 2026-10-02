import SwiftUI

struct VerseToRememberCard: View {
    let verse: HomeVerseRef?
    let canChooseAnother: Bool
    let onChooseAnother: () -> Void
    let onOpenVerse: (HomeVerseRef) -> Void
    let onOpenFavorites: () -> Void

    @State private var revealedWordCount = 0

    private var verseID: String {
        guard let verse else { return "empty" }
        return "\(verse.bookName)-\(verse.chapterNumber)-\(verse.verseNumber)"
    }

    private var words: [Substring] {
        verse?.verseText.split(separator: " ") ?? []
    }

    private var hiddenWordIndices: [Int] {
        let preferred = words.indices.filter { shouldHide(word: words[$0], at: $0) }
        if !preferred.isEmpty {
            return preferred
        }

        if let fallback = words.firstIndex(where: { $0.filter(\.isLetter).count >= 4 }) {
            return [fallback]
        }
        return []
    }

    private var allWordsRevealed: Bool {
        revealedWordCount >= hiddenWordIndices.count
    }

    private var practiceText: AttributedString {
        var result = AttributedString()

        for (index, word) in words.enumerated() {
            if index > words.startIndex {
                result.append(AttributedString(" "))
            }

            if let hiddenPosition = hiddenWordIndices.firstIndex(of: index) {
                if hiddenPosition < revealedWordCount {
                    var revealedWord = AttributedString(String(word))
                    revealedWord.foregroundColor = .red
                    result.append(revealedWord)
                } else {
                    let hiddenLength = max(3, word.filter(\.isLetter).count)
                    result.append(AttributedString(String(repeating: "＿", count: hiddenLength)))
                }
            } else {
                result.append(AttributedString(String(word)))
            }
        }

        return result
    }

    var body: some View {
        HeroCard(
            title: "Verse to Remember",
            subtitle: "Practice a verse from your Favorites",
            icon: "brain.head.profile",
            tint: .purple
        ) {
            if let verse {
                VStack(alignment: .leading, spacing: 12) {
                    Text(practiceText)
                        .font(.headline)
                        .italic()
                        .lineLimit(8)
                        .id(revealedWordCount)
                        .accessibilityLabel(
                            allWordsRevealed
                                ? verse.verseText
                                : "\(hiddenWordIndices.count - revealedWordCount) words remain hidden."
                        )

                    Text("\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        actionButton(
                            title: allWordsRevealed ? "Reset" : "Reveal",
                            systemImage: allWordsRevealed ? "arrow.counterclockwise" : "eye"
                        ) {
                            if allWordsRevealed {
                                revealedWordCount = 0
                            } else {
                                revealedWordCount += 1
                            }
                        }

                        actionButton(
                            title: "Another",
                            systemImage: "arrow.triangle.2.circlepath",
                            disabled: !canChooseAnother
                        ) {
                            revealedWordCount = 0
                            onChooseAnother()
                        }

                        actionButton(
                            title: "Read in Context",
                            systemImage: "book.pages"
                        ) {
                            onOpenVerse(verse)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Favorite a verse to turn it into a quick memory exercise here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    actionButton(title: "Open Favorites", systemImage: "heart") {
                        onOpenFavorites()
                    }
                }
            }
        }
        .onChange(of: verseID) { _, _ in
            revealedWordCount = 0
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(disabled ? Color.secondary : Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 4)
            .heroCardSurface(cornerRadius: AppDesignMetrics.compactControlCornerRadius)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }

    private func shouldHide(word: Substring, at index: Int) -> Bool {
        let letterCount = word.filter(\.isLetter).count
        return letterCount >= 4 && index % 4 == 2
    }
}
