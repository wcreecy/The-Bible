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
    /// How often each word is used, by Strong's number, once looked up.
    private(set) var usage: [String: OriginalWordUsage] = [:]
    /// Who each name in the current verse is, by Strong's number and verse, once looked up.
    private(set) var names: [String: [OriginalName]] = [:]

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

    /// Looks up how often a word is used, once. Words without a Strong's number have no count.
    func loadUsage(for word: OriginalWord) async {
        guard let strongs = word.strongsNumber, usage[strongs] == nil else { return }
        usage[strongs] = await OriginalWordsRepository.shared.usage(of: strongs, translation: translation)
    }

    /// Looks up who a name is in this verse, once. Most words aren't names and have none.
    func loadNames(for word: OriginalWord) async {
        guard let strongs = word.strongsNumber, names[nameKey(strongs)] == nil else { return }
        names[nameKey(strongs)] = await OriginalWordsRepository.shared.names(
            forStrongs: strongs,
            in: VerseLocation(bookName: bookName, chapter: chapter, verse: verse)
        )
    }

    /// Who the word is, if it's a name here: usually one person or place; several when the
    /// verse names more than one with the same number.
    func names(for word: OriginalWord) -> [OriginalName] {
        word.strongsNumber.flatMap { names[nameKey($0)] } ?? []
    }

    private func nameKey(_ strongs: String) -> String {
        "\(strongs)|\(chapter):\(verse)"
    }

    /// The English verse shown above the words: in the verse's own translation when it's in
    /// memory, otherwise in the reader's.
    var englishVerse: (text: String, translation: BibleTranslation)? {
        Self.verseText(
            VerseLocation(bookName: bookName, chapter: chapter, verse: verse),
            preferring: translation
        )
    }

    /// A verse's text in `translation` if it's in memory, otherwise in the reader's translation.
    static func verseText(
        _ location: VerseLocation,
        preferring translation: BibleTranslation
    ) -> (text: String, translation: BibleTranslation)? {
        let repository = BibleRepository.shared
        for candidate in [translation, repository.activeTranslation] {
            let match = repository.cachedBooks(for: candidate)
                .first { $0.name == location.bookName }?
                .chapters.first { $0.number == location.chapter }?
                .verses.first { $0.number == location.verse }
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
    /// The word whose list of verses is open.
    @State private var usageWord: OriginalWord?

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
                                    usage: word.strongsNumber.flatMap { model.usage[$0] },
                                    names: model.names(for: word),
                                    currentVerse: VerseLocation(
                                        bookName: model.bookName, chapter: model.chapter, verse: model.verse
                                    ),
                                    maximumHeight: geometry.size.height * 0.45,
                                    onShowVerses: { usageWord = word },
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
        // Also runs once the words have loaded, for a word chosen before they did.
        .task(id: selectedWord?.strongsNumber) {
            if let word = selectedWord {
                await model.loadUsage(for: word)
                await model.loadNames(for: word)
            }
        }
        .sheet(item: $usageWord) { word in
            WordUsageView(word: word, translation: model.translation, onOpen: openVerse)
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
                Text("Word for word, in the original’s order, so it won’t match the English wording. Bold is the meaning in this verse; gray is the dictionary’s.")
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

    /// Closes the sheets and opens the verse in the reader.
    private func openVerse(_ location: VerseLocation) {
        usageWord = nil
        dismiss()
        // Navigate after the sheets start dismissing so the reader can take over.
        DispatchQueue.main.async {
            AppRouter.shared.openBibleReference(
                book: location.bookName,
                chapter: location.chapter,
                verse: location.verse
            )
        }
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

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Text(word.original)
                    .font(.title3)
                    .foregroundStyle(.primary)
                // The meaning in this verse, then the dictionary's when it adds something.
                Text(word.contextGloss)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: maximumGlossWidth)
                    .fixedSize(horizontal: false, vertical: true)
                if let dictionary = word.dictionaryGloss {
                    Text(dictionary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: maximumGlossWidth)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
            .overlay(alignment: .topTrailing) {
                // The word isn't in every text; the entry panel says which.
                if word.textVariant != nil {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .accessibilityHidden(true)
                }
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
        if !word.contextGloss.isEmpty { parts.append(word.contextGloss) }
        if let dictionary = word.dictionaryGloss {
            parts.append(String(localized: "dictionary meaning \(dictionary)"))
        }
        if let number = word.displayStrongsNumber {
            parts.append(String(localized: "Strong’s \(number)"))
        }
        if let variant = word.textVariant {
            parts.append(variant.explanation)
        }
        return parts.joined(separator: ", ")
    }
}

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

/// Every verse that uses a word, grouped by book. Tapping one opens it in the reader.
private struct WordUsageView: View {
    @Environment(\.dismiss) private var dismiss

    let word: OriginalWord
    let translation: BibleTranslation
    let onOpen: (VerseLocation) -> Void

    @State private var verses: [VerseLocation] = []
    @State private var isLoading = true

    private var title: String {
        [word.displayStrongsNumber, word.entry?.gloss].compactMap { $0 }.joined(separator: " · ")
    }

    /// The verses (already in Bible order) in runs by book.
    private var books: [(name: String, verses: [VerseLocation])] {
        var groups: [(name: String, verses: [VerseLocation])] = []
        for verse in verses {
            if groups.last?.name == verse.bookName {
                groups[groups.count - 1].verses.append(verse)
            } else {
                groups.append((verse.bookName, [verse]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if verses.isEmpty {
                    ContentUnavailableView(
                        "No Verses",
                        systemImage: "text.magnifyingglass",
                        description: Text("No verses were found for this word.")
                    )
                } else {
                    List {
                        ForEach(books, id: \.name) { book in
                            Section {
                                ForEach(book.verses) { verse in
                                    row(for: verse)
                                }
                            } header: {
                                Text(verbatim: "\(book.name) · \(book.verses.count)")
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if let strongs = word.strongsNumber {
                verses = await OriginalWordsRepository.shared.verses(using: strongs, translation: translation)
            }
            isLoading = false
        }
        .presentationDetents([.large])
    }

    private func row(for verse: VerseLocation) -> some View {
        Button {
            onOpen(verse)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(verse.chapter):\(verse.verse)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let text = OriginalWordsModel.verseText(verse, preferring: translation)?.text {
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this verse in the reader")
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
private struct NameCard: View {
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

/// The dictionary entry for the chosen word, docked at the bottom of the sheet. A long entry
/// scrolls inside the panel instead of pushing the verse off screen.
private struct WordEntryPanel: View {
    let word: OriginalWord
    /// Nil until the count has loaded, or when the word has no Strong's number.
    let usage: OriginalWordUsage?
    /// Who the word is when it's a name in this verse; empty for any other word.
    let names: [OriginalName]
    let currentVerse: VerseLocation
    let maximumHeight: CGFloat
    let onShowVerses: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let variant = word.textVariant {
                Label(variant.explanation, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let usage {
                usageRow(usage)
            }
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
            if let first = usage.first, usage.verseCount > 1 {
                Text("First in \(first.reference)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
