import SwiftUI

#Preview("Hebrew") {
    NavigationStack {
        OriginalWordsView(bookName: "Genesis", chapter: 1, verse: 1, translation: .kjv)
    }
}

#Preview("Greek") {
    NavigationStack {
        OriginalWordsView(bookName: "John", chapter: 1, verse: 1, translation: .kjv)
    }
}

#Preview("Word Selected") {
    NavigationStack {
        OriginalWordsView(bookName: "John", chapter: 1, verse: 1, translation: .kjv, selectedWordID: 5)
    }
}

#Preview("Short Entry Selected") {
    NavigationStack {
        OriginalWordsView(bookName: "Genesis", chapter: 1, verse: 1, translation: .kjv, selectedWordID: 2)
    }
}

#Preview("Long Verse") {
    NavigationStack {
        OriginalWordsView(bookName: "Isaiah", chapter: 10, verse: 12, translation: .kjv)
    }
}


#Preview("Text Variant") {
    // 1 John 5:7: the word "in" is in the Greek text behind the KJV only.
    NavigationStack {
        OriginalWordsView(bookName: "1 John", chapter: 5, verse: 7, translation: .kjv, selectedWordID: 6)
    }
}

#Preview("Verses Using a Word") {
    WordUsageView(
        word: OriginalWord(
            id: 3, original: "אֱלֹהִים", transliteration: "'E.lo.Him", gloss: "God",
            strongsNumber: "H0430G",
            entry: OriginalWordEntry(lemma: "אֱלֹהִים", transliteration: "e.lo.him", gloss: "God", definition: ""),
            source: "L",
            parse: nil
        ),
        translation: .kjv,
        onOpen: { _ in }
    )
}

#Preview("Two Meanings") {
    // Matthew 2:16: the KJV says "mocked"; the in-context gloss is "he had been outwitted".
    NavigationStack {
        OriginalWordsView(bookName: "Matthew", chapter: 2, verse: 16, translation: .kjv, selectedWordID: 5)
    }
}


#Preview("Person") {
    // Exodus 4:14: Aaron, the 7th word.
    NavigationStack {
        OriginalWordsView(bookName: "Exodus", chapter: 4, verse: 14, translation: .kjv, selectedWordID: 7)
    }
}

#Preview("Place") {
    // Matthew 2:1: Bethlehem, the 6th word.
    NavigationStack {
        OriginalWordsView(bookName: "Matthew", chapter: 2, verse: 1, translation: .kjv, selectedWordID: 6)
    }
}

#Preview("Group") {
    // Mark 15:12: "the Jews", the 16th word (word numbers include words only some texts have).
    NavigationStack {
        OriginalWordsView(bookName: "Mark", chapter: 15, verse: 12, translation: .kjv, selectedWordID: 16)
    }
}

#Preview("Small Words Hidden") {
    // A separate defaults suite, so the preview's choice never touches the app's setting.
    let defaults = UserDefaults(suiteName: "WordStudyPreview") ?? .standard
    defaults.set(true, forKey: AppStorageKey.wordStudyHidesSmallWords)
    return NavigationStack {
        OriginalWordsView(bookName: "Isaiah", chapter: 10, verse: 12, translation: .kjv)
    }
    .defaultAppStorage(defaults)
}
