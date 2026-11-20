import SwiftUI

/// A verse shown with a word game's puzzle (Scramble, Hangman): as a clue with the answer
/// blanked out, or in full once the word is over.
struct GameVerse: Equatable {
    let text: String
    let reference: String
    let isClue: Bool
}

/// The source verse: a clue with the answer blanked out, or the whole verse once the word is over.
struct GameVerseCard: View {
    let verse: GameVerse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(verse.isClue ? "Verse Clue" : "From the Verse", systemImage: verse.isClue ? "text.quote" : "book.pages")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(verse.text)
                .font(.callout)
                .fontDesign(.serif)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verse.reference)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(verse.isClue ? "Verse clue" : "From the verse")
        // VoiceOver would read each blank as "underscore".
        .accessibilityValue("\(verse.text.replacing(/_+/, with: "blank")), \(verse.reference)")
    }
}
