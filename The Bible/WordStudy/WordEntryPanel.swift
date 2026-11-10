import SwiftUI

extension OriginalTextVariant {
    /// Why the word isn't in every text, in a sentence.
    var explanation: String {
        switch self {
        case .traditionalGreekOnly:
            String(localized: "In the Greek text behind the KJV, but not in modern critical editions.")
        case .criticalGreekOnly:
            String(localized: "In modern critical editions, but not in the Greek text behind the KJV.")
        case .qere:
            String(localized: "Read from the scribes’ margin (the Qere); the written text differs.")
        case .restored:
            String(localized: "Restored from a parallel passage, because the manuscript is missing it.")
        }
    }
}

extension OriginalName.Kind {
    var label: LocalizedStringKey {
        switch self {
        case .male: "Man"
        case .female: "Woman"
        case .group: "People group"
        case .place: "Place"
        case .supernatural: "Supernatural being"
        case .time: "Time"
        case .musical: "Musical term"
        case .title: "Title"
        case .star: "Star"
        case .language: "Language"
        case .other: "Name"
        }
    }

    var symbol: String {
        switch self {
        case .male, .female: "person.fill"
        case .group: "person.3.fill"
        case .place: "mappin.circle.fill"
        case .supernatural: "sparkles"
        case .time: "calendar"
        case .musical: "music.note"
        case .star: "star.fill"
        case .language: "text.bubble.fill"
        case .title, .other: "tag.fill"
        }
    }
}

/// Who a name is: what the source says about the person, or where the place is.
struct NameCard: View {
    let name: OriginalName

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: name.kind.symbol)
                    .foregroundStyle(Color.accentColor)
                Text(name.name)
                    .font(.headline)
                Text(name.kind.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !name.description.isEmpty {
                Text(name.description)
                    .font(.subheadline)
            }
            fact("Parents", name.parents)
            fact("Siblings", name.siblings)
            fact("Spouse", name.partners)
            fact("Children", name.offspring)
            if !name.area.isEmpty {
                Text(name.area)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func fact(_ label: LocalizedStringKey, _ value: String) -> some View {
        if !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 62, alignment: .leading)
                Text(value)
                    .font(.subheadline)
            }
        }
    }
}

/// The dictionary entry for the chosen word. Docked at the bottom of the sheet, a long entry
/// scrolls inside the panel instead of pushing the verse off screen. With no `maximumHeight` it
/// fills a sheet of its own, which is how it appears at accessibility text sizes.
struct WordEntryPanel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let word: OriginalWord
    /// Nil until the count has loaded, or when the word has no Strong's number.
    let usage: OriginalWordUsage?
    /// Who the word is when it's a name in this verse; empty for any other word.
    let names: [OriginalName]
    let currentVerse: VerseLocation
    /// The height the docked panel may take; nil when the entry fills a sheet of its own.
    let maximumHeight: CGFloat?
    let onShowVerses: () -> Void
    let onClose: () -> Void

    var body: some View {
        if let maximumHeight {
            VStack(alignment: .leading, spacing: 8) {
                top
                ViewThatFits(in: .vertical) {
                    details
                    ScrollView {
                        details
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    // Shows that a long entry continues below the panel's edge.
                    .scrollIndicatorsFlash(trigger: word.id)
                    .scrollIndicatorsFlash(onAppear: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: maximumHeight, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
            .overlay(alignment: .top) {
                Divider()
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                top
                details
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    /// The word, why it may be missing from some texts, and how often it's used.
    @ViewBuilder
    private var top: some View {
        header
        if let variant = word.textVariant {
            Label(variant.explanation, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let usage {
            usageRow(usage)
        }
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Too wide for one row: the word and close button, then its transliteration and number.
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    lemma
                    Spacer(minLength: 8)
                    if maximumHeight != nil {
                        closeButton
                    }
                }
                transliteration
                strongsChip
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                lemma
                transliteration
                strongsChip
                Spacer(minLength: 8)
                if maximumHeight != nil {
                    closeButton
                }
            }
        }
    }

    private var lemma: some View {
        Text(word.entry?.lemma ?? word.original)
            .font(.title2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var transliteration: some View {
        if let transliteration = word.entry?.transliteration, !transliteration.isEmpty {
            Text(transliteration)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Never wraps: "H175" split over two lines reads as two numbers.
    @ViewBuilder
    private var strongsChip: some View {
        if let number = word.displayStrongsNumber {
            Text(number)
                .font(.caption.monospaced().weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.accentColor)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close Entry")
    }

    /// The two meanings, labeled: how the word reads in this verse, and the dictionary's. When the
    /// dictionary only repeats the first, there is just "Meaning".
    @ViewBuilder
    private var meanings: some View {
        if let dictionary = word.dictionaryGloss {
            labeledMeaning("In this verse", word.contextGloss, details: thisWord)
            labeledMeaning("Dictionary meaning", dictionary, details: [])
        } else if !word.contextGloss.isEmpty {
            labeledMeaning("Meaning", word.contextGloss, details: thisWord)
        }
    }

    /// The word as written in this verse with its transliteration (which the tile doesn't show),
    /// and its grammar.
    private var thisWord: [String] {
        [
            [word.original, word.transliteration].filter { !$0.isEmpty }.joined(separator: " · "),
            word.parse ?? "",
        ].filter { !$0.isEmpty }
    }

    private func labeledMeaning(_ label: LocalizedStringKey, _ text: String, details: [String]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.headline)
            ForEach(details, id: \.self) { detail in
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "Used 2,599 times in 2,246 verses", opening the list of them. A word used only here has
    /// nothing else to open.
    @ViewBuilder
    private func usageRow(_ usage: OriginalWordUsage) -> some View {
        let hasOtherVerses = usage.verseCount > 1 || usage.first != currentVerse
        if hasOtherVerses {
            Button(action: onShowVerses) {
                HStack(spacing: 8) {
                    Image(systemName: "text.magnifyingglass")
                        .foregroundStyle(Color.accentColor)
                    usageText(usage)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows every verse that uses this word")
        } else {
            usageText(usage)
        }
    }

    private func usageText(_ usage: OriginalWordUsage) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(summary(of: usage))
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let first = usage.first, usage.verseCount > 1 {
                Text("First in \(first.reference)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summary(of usage: OriginalWordUsage) -> LocalizedStringKey {
        let words = usage.wordCount.formatted()
        let verses = usage.verseCount.formatted()
        if usage.wordCount == 1 { return "Used once" }
        if usage.verseCount == 1 { return "Used \(words) times in 1 verse" }
        return "Used \(words) times in \(verses) verses"
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Most people share a name, so at most a few, in case a verse names several.
            ForEach(names.prefix(3)) { name in
                NameCard(name: name)
            }
            if names.count > 3 {
                Text("\(names.count - 3) more with this name in this verse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            meanings
            if let entry = word.entry {
                // Some entries have no English text beyond the gloss once the scholarly notes are cut.
                if !entry.definition.isEmpty {
                    Text(entry.definition)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("No dictionary entry for this word.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
