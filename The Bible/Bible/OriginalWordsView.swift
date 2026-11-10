import SwiftUI

/// Loads the Hebrew or Greek words of one verse and steps through the verses around it.
@MainActor
@Observable
final class OriginalWordsModel {
    let bookName: String
    let translation: BibleTranslation
    private(set) var chapter: Int
    private(set) var verse: Int
    private(set) var words: [OriginalWord] = []
    private(set) var isLoading = true

    init(bookName: String, chapter: Int, verse: Int, translation: BibleTranslation) {
        self.bookName = bookName
        self.chapter = chapter
        self.verse = verse
        self.translation = translation
    }

    var language: OriginalLanguage {
        Canon.isOld(bookName) ? .hebrew : .greek
    }

    func load() async {
        isLoading = true
        // The reader has the Bible loaded already; this matters only when the sheet opens first.
        if BibleRepository.shared.cachedBooks.isEmpty {
            _ = await BibleRepository.shared.loadAllBooks()
        }
        words = await OriginalWordsRepository.shared.words(
            bookName: bookName,
            chapter: chapter,
            verse: verse,
            translation: translation
        )
        isLoading = false
    }

    /// The English verse shown above the words: in the verse's own translation when it's in
    /// memory, otherwise in the reader's.
    var englishVerse: (text: String, translation: BibleTranslation)? {
        let repository = BibleRepository.shared
        let candidates = [translation, repository.activeTranslation]
        for candidate in candidates {
            let match = repository.cachedBooks(for: candidate)
                .first { $0.name == bookName }?
                .chapters.first { $0.number == chapter }?
                .verses.first { $0.number == self.verse }
            if let match, !match.isOmitted {
                return (match.text, candidate)
            }
        }
        return nil
    }

    // MARK: Stepping

    /// The chapter and verse counts of the KJV's order, which every translation here follows.
    private var chapterVerseCounts: [Int] {
        BibleRepository.shared.cachedBooks
            .first { $0.name == bookName }?
            .chapters.map(\.verses.count) ?? []
    }

    var canStepBack: Bool { verse > 1 || chapter > 1 }

    var canStepForward: Bool {
        let counts = chapterVerseCounts
        guard chapter <= counts.count else { return false }
        return verse < counts[chapter - 1] || chapter < counts.count
    }

    func stepBack() {
        if verse > 1 {
            verse -= 1
        } else if chapter > 1 {
            chapter -= 1
            let counts = chapterVerseCounts
            verse = chapter <= counts.count ? max(counts[chapter - 1], 1) : 1
        }
    }

    func stepForward() {
        let counts = chapterVerseCounts
        guard chapter <= counts.count else { return }
        if verse < counts[chapter - 1] {
            verse += 1
        } else if chapter < counts.count {
            chapter += 1
            verse = 1
        }
    }
}

/// An interlinear of one verse: the English verse, then its Hebrew or Greek words in the
/// verse's word order, wrapping left to right like the English above them (Hebrew too, so the
/// word order lines up with the English). Tap a word for its dictionary entry; step through
/// neighboring verses with the bottom bar.
struct OriginalWordsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: OriginalWordsModel
    /// The word whose dictionary entry is showing. Choosing another replaces it.
    @State private var selectedWordID: Int?
    /// Choosing a word in the half-height sheet raises it, so the docked entry has room.
    @State private var detent: PresentationDetent = .medium

    /// `selectedWordID` opens with a word's entry showing (its place in the verse, from 1).
    init(
        bookName: String,
        chapter: Int,
        verse: Int,
        translation: BibleTranslation,
        selectedWordID: Int? = nil
    ) {
        _model = State(initialValue: OriginalWordsModel(
            bookName: bookName,
            chapter: chapter,
            verse: verse,
            translation: translation
        ))
        _selectedWordID = State(initialValue: selectedWordID)
    }

    private var selectedWord: OriginalWord? {
        model.words.first { $0.id == selectedWordID }
    }

    var body: some View {
        Group {
            if model.isLoading && model.words.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.words.isEmpty {
                ContentUnavailableView(
                    "No Word Data",
                    systemImage: "character.book.closed",
                    description: Text("This verse has no Hebrew or Greek word data.")
                )
            } else {
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                englishVerse
                                interlinear
                                if selectedWord == nil {
                                    hint
                                }
                            }
                            .padding()
                        }
                        // The entry docks at the bottom, so the verse never moves while
                        // someone taps from word to word.
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            if let word = selectedWord {
                                WordEntryPanel(
                                    word: word,
                                    maximumHeight: geometry.size.height * 0.45,
                                    onClose: { select(nil) }
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .onChange(of: selectedWordID) { _, newValue in
                            guard let newValue else { return }
                            // Keep the chosen word in sight above the panel.
                            withAnimation(.snappy) {
                                proxy.scrollTo(newValue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(model.bookName) \(model.chapter):\(model.verse)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    Haptics.selection()
                    model.stepBack()
                } label: {
                    Label("Previous Verse", systemImage: "chevron.left")
                }
                .disabled(!model.canStepBack)

                Spacer()

                Button {
                    Haptics.selection()
                    model.stepForward()
                } label: {
                    Label("Next Verse", systemImage: "chevron.right")
                }
                .disabled(!model.canStepForward)
            }
        }
        .task(id: verseKey) {
            await model.load()
        }
        .onChange(of: verseKey) {
            // A new verse has different words, so its entry panel starts closed.
            selectedWordID = nil
        }
        .presentationDetents([.medium, .large], selection: $detent)
    }

    private var verseKey: String {
        "\(model.chapter):\(model.verse)"
    }

    // MARK: Sections

    @ViewBuilder
    private var englishVerse: some View {
        if let verse = model.englishVerse {
            VStack(alignment: .leading, spacing: 4) {
                Text(verse.translation.abbreviation)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(verse.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var interlinear: some View {
        let title: LocalizedStringKey = model.language == .hebrew ? "Hebrew" : "Greek"
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                // The original's grammar and a literal gloss never line up with a translation.
                Text("Word for word, in the original’s order, so it won’t match the English wording.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            InterlinearFlowLayout(spacing: 8) {
                ForEach(model.words) { word in
                    InterlinearWordTile(
                        word: word,
                        isSelected: word.id == selectedWordID,
                        onSelect: { select(word.id == selectedWordID ? nil : word) }
                    )
                    .id(word.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hint: some View {
        Text("Tap a word to see its meaning.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    /// Shows a word's entry, or closes the panel when `word` is nil.
    private func select(_ word: OriginalWord?) {
        Haptics.selection()
        withAnimation(.snappy) {
            selectedWordID = word?.id
            if word != nil, detent == .medium {
                detent = .large
            }
        }
    }
}

/// Wraps its children onto rows, left to right, and stretches every child in a row to the row's
/// height, so a tile with a two-line gloss doesn't sit taller than its neighbors.
private struct InterlinearFlowLayout: Layout {
    var spacing: CGFloat

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let width = measuredSize(of: subviews[index]).width
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(width: width, height: row.height)
                )
                x += width + spacing
            }
        }
    }

    /// A tile's size once its gloss has wrapped. The ideal size alone reports the width the text
    /// is capped to but the height of the unwrapped line, so a two-line gloss would overflow its row.
    private func measuredSize(of subview: LayoutSubview) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        return subview.sizeThatFits(ProposedViewSize(width: ideal.width, height: nil))
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = measuredSize(of: subviews[index])
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// One word of the interlinear: the original over its transliteration, its meaning in this
/// verse, and its Strong's number.
private struct InterlinearWordTile: View {
    /// Long glosses wrap instead of stretching a tile across the row.
    @ScaledMetric(relativeTo: .caption) private var maximumGlossWidth: CGFloat = 120

    let word: OriginalWord
    let isSelected: Bool
    let onSelect: () -> Void

    private var gloss: String {
        word.gloss.isEmpty ? (word.entry?.gloss ?? "") : word.gloss
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Text(word.original)
                    .font(.title3)
                    .foregroundStyle(.primary)
                if !word.transliteration.isEmpty {
                    Text(word.transliteration)
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                Text(gloss)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: maximumGlossWidth)
                    .fixedSize(horizontal: false, vertical: true)
                if let number = word.displayStrongsNumber {
                    Text(number)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            // Takes the height of its row (see InterlinearFlowLayout), so tiles side by side match.
            .frame(maxHeight: .infinity)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(.background.secondary),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Shows the dictionary entry")
    }

    private var accessibilityLabel: String {
        var parts = [word.original]
        if !word.transliteration.isEmpty { parts.append(word.transliteration) }
        if !gloss.isEmpty { parts.append(gloss) }
        if let number = word.displayStrongsNumber {
            parts.append(String(localized: "Strong’s \(number)"))
        }
        return parts.joined(separator: ", ")
    }
}

/// The dictionary entry for the chosen word, docked at the bottom of the sheet. A long entry
/// scrolls inside the panel instead of pushing the verse off screen.
private struct WordEntryPanel: View {
    let word: OriginalWord
    let maximumHeight: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
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
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(word.entry?.lemma ?? word.original)
                .font(.title2)
            if let transliteration = word.entry?.transliteration, !transliteration.isEmpty {
                Text(transliteration)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            if let number = word.displayStrongsNumber {
                Text(number)
                    .font(.caption.monospaced().weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Entry")
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let entry = word.entry {
                if !entry.gloss.isEmpty {
                    Text(entry.gloss)
                        .font(.headline)
                }
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
