import SwiftUI

/// An interlinear of one verse: the English verse, then its Hebrew or Greek words in the
/// verse's word order, wrapping left to right like the English above them (Hebrew too, so the
/// word order lines up with the English). Tap a word for its dictionary entry; step through
/// neighboring verses with the bottom bar.
struct OriginalWordsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(AppStorageKey.wordStudyHidesSmallWords) private var hidesSmallWords = false
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

    /// The words shown as tiles: all of them, or without the small ones.
    private var visibleWords: [OriginalWord] {
        hidesSmallWords ? model.words.filter { !$0.isSmallWord } : model.words
    }

    /// At accessibility text sizes the entry is too big to dock beside the tiles, so it opens as
    /// a sheet of its own.
    private var showsEntryInSheet: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var currentVerse: VerseLocation {
        VerseLocation(bookName: model.bookName, chapter: model.chapter, verse: model.verse)
    }

    /// The entry panel for a word, docked (with a height) or filling its own sheet (without).
    private func entryPanel(for word: OriginalWord, maximumHeight: CGFloat?) -> WordEntryPanel {
        WordEntryPanel(
            word: word,
            usage: word.strongsNumber.flatMap { model.usage[$0] },
            names: model.names(for: word),
            currentVerse: currentVerse,
            maximumHeight: maximumHeight,
            onShowVerses: { usageWord = word },
            onClose: { select(nil) }
        )
    }

    /// Changes as a word's usage and names arrive, which makes the panel taller.
    private var entryContentToken: Int {
        model.usage.count + model.names.count
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
                            if let word = selectedWord, !showsEntryInSheet {
                                entryPanel(for: word, maximumHeight: geometry.size.height * 0.45)
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
                        // The panel grows when its usage and names arrive, and a word chosen
                        // before the verse loaded has no tile to scroll to until it has, so
                        // look again then.
                        .onChange(of: entryContentToken) { scrollToSelectedWord(proxy) }
                        .onChange(of: model.words.count) { scrollToSelectedWord(proxy) }
                        .sheet(isPresented: entrySheetIsPresented) {
                            entrySheet
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
        // The verse list opens from the docked panel, or from the entry sheet at accessibility
        // sizes; only one of the two is ever the presenter.
        .sheet(item: usageWordBinding(forEntrySheet: false)) { word in
            WordUsageView(word: word, translation: model.translation, onOpen: openVerse)
        }
        .onChange(of: hidesSmallWords) {
            // Hiding the small words closes the entry of one that just disappeared.
            if selectedWord?.isSmallWord == true, hidesSmallWords {
                selectedWordID = nil
            }
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

    // MARK: The entry as a sheet (accessibility sizes)

    private var entrySheetIsPresented: Binding<Bool> {
        Binding(
            get: { showsEntryInSheet && selectedWord != nil },
            set: { if !$0 { selectedWordID = nil } }
        )
    }

    private func usageWordBinding(forEntrySheet: Bool) -> Binding<OriginalWord?> {
        Binding(
            get: { showsEntryInSheet == forEntrySheet ? usageWord : nil },
            set: { usageWord = $0 }
        )
    }

    @ViewBuilder
    private var entrySheet: some View {
        if let word = selectedWord {
            NavigationStack {
                ScrollView {
                    entryPanel(for: word, maximumHeight: nil)
                        .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { select(nil) }
                    }
                }
                .sheet(item: usageWordBinding(forEntrySheet: true)) { word in
                    WordUsageView(word: word, translation: model.translation, onOpen: openVerse)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func scrollToSelectedWord(_ proxy: ScrollViewProxy) {
        guard let selectedWordID, !showsEntryInSheet else { return }
        withAnimation(.snappy) {
            proxy.scrollTo(selectedWordID)
        }
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
                HStack(alignment: .center, spacing: 12) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    smallWordsToggle
                }
                // The original's grammar and a literal gloss never line up with a translation.
                Text("Word for word, in the original’s order, so it won’t match the English wording. Bold is the meaning in this verse; gray is the dictionary’s.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            InterlinearFlowLayout(spacing: 8) {
                ForEach(visibleWords) { word in
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

    /// Hides the articles, conjunctions, and Hebrew object markers that make a long verse long.
    /// Only offered when the verse has any.
    @ViewBuilder
    private var smallWordsToggle: some View {
        let smallWordCount = model.words.filter(\.isSmallWord).count
        let showTitle: LocalizedStringKey = smallWordCount == 1
            ? "Show 1 small word"
            : "Show \(smallWordCount) small words"
        if smallWordCount > 0 {
            Button {
                Haptics.selection()
                withAnimation(.snappy) {
                    hidesSmallWords.toggle()
                }
            } label: {
                Text(hidesSmallWords ? showTitle : "Hide small words")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityHint("Articles, conjunctions, and markers with no English meaning")
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
