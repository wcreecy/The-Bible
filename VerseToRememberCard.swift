import SwiftUI

struct VerseToRememberCard: View {
    let verse: HomeVerseRef?
    var usesExpandedLayout = false
    let canChooseAnother: Bool
    let onChooseAnother: () -> Void
    let onOpenVerse: (HomeVerseRef) -> Void
    let onOpenFavorites: () -> Void

    @State private var revealedWordCount = 0
    @State private var hiddenWordIndices: [Int] = []

    private var verseID: String {
        guard let verse else { return "empty" }
        return "\(verse.bookName)-\(verse.chapterNumber)-\(verse.verseNumber)"
    }

    private var words: [Substring] {
        verse?.verseText.split(separator: " ") ?? []
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
            tint: .purple,
            titleFont: usesExpandedLayout ? .title3 : .headline
        ) {
            if let verse {
                VStack(alignment: .leading, spacing: 12) {
                    Text(practiceText)
                        .font(usesExpandedLayout ? .title2 : .headline)
                        .italic()
                        .lineLimit(usesExpandedLayout ? 10 : 8)
                        .id(revealedWordCount)
                        .accessibilityLabel(
                            allWordsRevealed
                                ? verse.verseText
                                : "\(hiddenWordIndices.count - revealedWordCount) words remain hidden."
                        )

                    Text("\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)")
                        .font((usesExpandedLayout ? Font.headline : Font.subheadline).weight(.semibold))
                        .foregroundStyle(.secondary)

                    if usesExpandedLayout {
                        Spacer(minLength: 16)
                    }

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
                .frame(
                    maxWidth: .infinity,
                    minHeight: usesExpandedLayout ? 500 : nil,
                    alignment: .topLeading
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Favorite a verse to turn it into a quick memory exercise here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    actionButton(title: "Open Favorites", systemImage: "heart") {
                        onOpenFavorites()
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: usesExpandedLayout ? 500 : nil,
                    alignment: .topLeading
                )
            }
        }
        .onAppear {
            randomizeHiddenWords()
        }
        .onChange(of: verseID) { _, _ in
            randomizeHiddenWords()
        }
    }

    private func randomizeHiddenWords() {
        let eligibleIndices = words.indices.filter {
            words[$0].filter(\.isLetter).count >= 4
        }
        let desiredCount = max(1, (words.count + 1) / 4)

        hiddenWordIndices = Array(eligibleIndices.shuffled().prefix(desiredCount)).sorted()
        revealedWordCount = 0
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
                    .font((usesExpandedLayout ? Font.footnote : Font.caption).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(disabled ? Color.secondary : Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: usesExpandedLayout ? 64 : 52)
            .padding(.horizontal, 4)
            .heroCardSurface(cornerRadius: AppDesignMetrics.compactControlCornerRadius)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}
