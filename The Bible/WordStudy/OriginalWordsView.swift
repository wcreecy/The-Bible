import SwiftUI

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
