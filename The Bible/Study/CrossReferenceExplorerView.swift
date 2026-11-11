import SwiftUI
import SwiftData

/// An entry point from the Study screen into the global connection index.
struct CrossReferenceExplorerEntryCard: View {
    var body: some View {
        NavigationLink {
            CrossReferenceExplorerView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Scripture Connections")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Explore curated links between passages")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppDesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens curated Scripture connections")
    }
}

/// A searchable index of editorially curated connections across Scripture.
struct CrossReferenceExplorerView: View {
    @Query(sort: \SavedCrossReference.savedAt, order: .reverse) private var savedConnections: [SavedCrossReference]

    @State private var entries: [CrossReferenceExplorerEntry] = []
    /// Worked out once per connection when the page loads, so filtering doesn't redo it per keystroke.
    @State private var searchDetails: [Int: SearchDetails] = [:]
    @State private var sections: [CrossReferenceExplorerSection] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var searchScope: CrossReferenceSearchScope = .both
    @State private var selectedSourceBook: String?
    @State private var selectedConnectionType: CrossReferenceConnectionType?
    @State private var isShowingSavedOnly = false
    @State private var selectedEntry: CrossReferenceExplorerEntry?
    @State private var studyTimeSourceID = UUID()

    private var sourceBookNames: [String] {
        let availableBooks = Set(entries.map(\.bookName))
        return BibleCanon.canonicalOrder().filter(availableBooks.contains)
    }

    private var savedEntryIDs: Set<Int> {
        Set(savedConnections.map(\.entryID))
    }

    private var hasActiveFilters: Bool {
        selectedSourceBook != nil || selectedConnectionType != nil || isShowingSavedOnly || searchScope != .both
    }

    var body: some View {
        List {
            CrossReferenceExplorerIntroduction()

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading curated connections…")
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if isShowingSavedOnly && savedEntryIDs.isEmpty {
                ContentUnavailableView {
                    Label("No Saved Connections", systemImage: "bookmark")
                } description: {
                    Text("Open a connection and tap the bookmark to save it here.")
                } actions: {
                    Button("Show All Connections") {
                        isShowingSavedOnly = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowSeparator(.hidden)
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.entries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            CrossReferenceExplorerRow(
                                entry: entry,
                                isSaved: savedEntryIDs.contains(entry.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the side-by-side Scripture preview")
                        }
                    } header: {
                        Text("\(section.bookName) · \(section.entries.count) connections")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Scripture Connections")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search Genesis 1:1, John 3:16, or a topic"
        )
        .searchScopes($searchScope) {
            ForEach(CrossReferenceSearchScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Source Book", selection: $selectedSourceBook) {
                        Text("All Books").tag(String?.none)
                        ForEach(sourceBookNames, id: \.self) { bookName in
                            Text(bookName).tag(Optional(bookName))
                        }
                    }

                    Picker("How the passages connect", selection: $selectedConnectionType) {
                        Text("Any connection").tag(CrossReferenceConnectionType?.none)
                        ForEach(CrossReferenceConnectionType.allCases) { type in
                            Label(type.title, systemImage: type.systemImage)
                                .tag(Optional(type))
                        }
                    }

                    Toggle("Saved Only", isOn: $isShowingSavedOnly)
                } label: {
                    Label(
                        "Filter connections",
                        systemImage: hasActiveFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
            }

            if hasActiveFilters {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: clearFilters) {
                        Label("Clear Filters", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .task {
            let loaded = await CrossReferenceExplorerEntry.loadAll()
            searchDetails = Dictionary(
                loaded.map { ($0.id, SearchDetails(entry: $0)) },
                uniquingKeysWith: { first, _ in first }
            )
            entries = loaded
            recomputeSections()
            isLoading = false
        }
        .onAppear {
            StudyTimeTracker.shared.start(studyTimeSourceID)
        }
        .onDisappear {
            StudyTimeTracker.shared.stop(studyTimeSourceID)
        }
        .onChange(of: searchText) { _, _ in recomputeSections() }
        .onChange(of: searchScope) { _, _ in recomputeSections() }
        .onChange(of: selectedSourceBook) { _, _ in recomputeSections() }
        .onChange(of: selectedConnectionType) { _, _ in recomputeSections() }
        .onChange(of: isShowingSavedOnly) { _, _ in recomputeSections() }
        .onChange(of: savedConnections.map(\.entryID)) { _, _ in recomputeSections() }
        .sheet(item: $selectedEntry) { entry in
            CrossReferencePreviewSheet(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
        }
    }

    private func recomputeSections() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // A query that reads as a verse ("John 3:16", "Jn 3:16") matches by verse range, so
        // John 3:1 doesn't also find John 3:10 or 1 John 3:1. Anything else matches as text.
        let searchedReference = query.isEmpty ? nil : BibleReferenceLinker.parse(query)
        let filteredEntries = entries.filter { entry in
            let details = searchDetails[entry.id]
            guard selectedSourceBook == nil || entry.bookName == selectedSourceBook else {
                return false
            }
            guard selectedConnectionType == nil || details?.connectionType == selectedConnectionType else {
                return false
            }
            guard !isShowingSavedOnly || savedEntryIDs.contains(entry.id) else {
                return false
            }
            guard !query.isEmpty else { return true }

            let matchesSource: Bool
            let matchesRelated: Bool
            let matchesExplanation: Bool
            if let searchedReference {
                matchesSource = entry.sourcePassage.overlaps(searchedReference)
                matchesRelated = details?.target?.overlaps(searchedReference) == true
                matchesExplanation = false
            } else {
                matchesSource = entry.sourceReference.localizedCaseInsensitiveContains(query)
                matchesRelated = entry.relatedReference.localizedCaseInsensitiveContains(query)
                matchesExplanation = details?.explanation?.localizedCaseInsensitiveContains(query) == true
            }

            switch searchScope {
            case .source:
                return matchesSource
            case .related:
                return matchesRelated
            case .both:
                return matchesSource || matchesRelated || matchesExplanation
            }
        }

        let bookOrder = Dictionary(
            uniqueKeysWithValues: BibleCanon.canonicalOrder().enumerated().map { ($0.element, $0.offset) }
        )
        sections = Dictionary(grouping: filteredEntries, by: \.bookName)
            .map { bookName, entries in
                CrossReferenceExplorerSection(
                    bookName: bookName,
                    entries: entries.sorted {
                        ($0.chapterNumber, $0.sourceVerse, $0.id) < ($1.chapterNumber, $1.sourceVerse, $1.id)
                    }
                )
            }
            .sorted {
                (bookOrder[$0.bookName] ?? .max, $0.bookName) < (bookOrder[$1.bookName] ?? .max, $1.bookName)
            }
    }

    private func clearFilters() {
        selectedSourceBook = nil
        selectedConnectionType = nil
        isShowingSavedOnly = false
        searchScope = .both
    }
}

/// What filtering needs to know about one connection.
private struct SearchDetails {
    let target: PassageReference?
    let explanation: String?
    let connectionType: CrossReferenceConnectionType?

    init(entry: CrossReferenceExplorerEntry) {
        target = PassageReferenceParser.parseList(
            entry.relatedReference,
            book: entry.bookName,
            chapter: entry.chapterNumber
        ).first
        explanation = entry.writtenExplanation
        connectionType = explanation.map(CrossReferenceConnectionType.classify)
    }
}

private enum CrossReferenceSearchScope: String, CaseIterable, Identifiable {
    case both
    case source
    case related

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .both: "All Fields"
        case .source: "Source Passage"
        case .related: "Related Passage"
        }
    }
}

private struct CrossReferenceExplorerSection: Identifiable {
    let bookName: String
    let entries: [CrossReferenceExplorerEntry]

    var id: String { bookName }
}

private struct CrossReferencePreviewSheet: View {
    let entry: CrossReferenceExplorerEntry

    @Environment(\.dismiss) private var dismiss
    @State private var preview: CrossReferencePreview?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let preview {
                        CrossReferencePassagesPreview(
                            source: preview.source,
                            target: preview.target
                        )

                        if let explanation = preview.explanation {
                            CrossReferenceExplanationPreview(text: explanation)
                        }
                    } else {
                        ProgressView("Loading passages…")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .padding()
            }
            .navigationTitle("Scripture Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .scriptureConnectionActions(preview.map { _ in ScriptureConnectionNote(entry: entry) })
            .task {
                preview = await CrossReferencePreviewLoader.load(entry: entry)
            }
        }
    }
}

private struct CrossReferencePassagesPreview: View {
    let source: CrossReferencePreview.Passage
    let target: CrossReferencePreview.Passage

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                CrossReferencePassagePreview(passage: source)
                CrossReferencePassagePreview(passage: target)
            }

            VStack(alignment: .leading, spacing: 16) {
                CrossReferencePassagePreview(passage: source)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                    Image(systemName: "arrow.up")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)

                CrossReferencePassagePreview(passage: target)
            }
        }
    }
}

private struct CrossReferencePassagePreview: View {
    let passage: CrossReferencePreview.Passage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(passage.reference.displayTitle) · \(BibleRepository.shared.activeTranslation.abbreviation)")
                .font(.headline)
                .foregroundStyle(.tint)

            Text("“\(passage.text)”")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                openInBible()
            } label: {
                Label("Open in Bible", systemImage: "book")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Opens this passage in the Bible reader")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .heroCardSurface()
    }

    private func openInBible() {
        let destination = passage.reference
        dismiss()

        DispatchQueue.main.async {
            AppRouter.shared.openBibleReference(
                book: destination.bookName,
                chapter: destination.startChapter,
                verse: destination.startVerse ?? 1
            )
        }
    }
}

private struct CrossReferenceExplanationPreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Relationship")
                .font(.subheadline.weight(.semibold))

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CrossReferencePreview {
    struct Passage {
        let reference: PassageReference
        let text: String
    }

    let source: Passage
    let target: Passage
    let explanation: String?
}

@MainActor
private enum CrossReferencePreviewLoader {
    static func load(entry: CrossReferenceExplorerEntry) async -> CrossReferencePreview? {
        let sourceReference = PassageReference(
            bookName: entry.bookName,
            startChapter: entry.chapterNumber,
            startVerse: entry.sourceVerse,
            endChapter: entry.chapterNumber,
            endVerse: entry.sourceVerse
        )
        guard let targetReference = PassageReferenceParser.parseList(
            entry.relatedReference,
            book: entry.bookName,
            chapter: entry.chapterNumber
        ).first else {
            return nil
        }

        let books = await BibleRepository.shared.loadAllBooks()
        return CrossReferencePreview(
            source: .init(
                reference: sourceReference,
                text: passageText(for: sourceReference, in: books)
            ),
            target: .init(
                reference: targetReference,
                text: passageText(for: targetReference, in: books)
            ),
            explanation: entry.relationshipDescription
        )
    }

    /// Returns the complete requested passage so the sheet can grow and scroll for longer references.
    private static func passageText(for reference: PassageReference, in books: [Book]) -> String {
        guard let book = books.first(where: { $0.name == reference.bookName }) else {
            return "Passage unavailable."
        }

        let verses = book.chapters
            .filter { $0.number >= reference.startChapter && $0.number <= reference.endChapter }
            .flatMap { chapter in
                chapter.verses.filter { verse in
                    if verse.isOmitted { return false }
                    guard let startVerse = reference.startVerse else { return true }
                    if chapter.number == reference.startChapter, verse.number < startVerse { return false }
                    if let endVerse = reference.endVerse,
                       chapter.number == reference.endChapter,
                       verse.number > endVerse {
                        return false
                    }
                    return true
                }
            }

        let text = verses
            .map { "\($0.number) \($0.text)" }
            .joined(separator: " ")
        guard !text.isEmpty else { return "Passage unavailable." }
        return text
    }
}

private struct CrossReferenceExplorerIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Curated Scripture Connections", systemImage: "arrow.triangle.branch")
                .font(.headline)

            Text("Explore selected passages linked by direct quotation, fulfilled prophecy, shared words or themes, or the same event. Select one for context and explanation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
    }
}

private struct CrossReferenceExplorerRow: View {
    let entry: CrossReferenceExplorerEntry
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.sourceReference)
                    .font(.subheadline.weight(.semibold))

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)

                Text(entry.relatedReference)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)

            Text(entry.relationshipDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let connectionType = entry.connectionType {
                    Label(connectionType.title, systemImage: connectionType.systemImage)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tint)
                }

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Saved connection")
                }
            }
        }
        .padding(.vertical, 3)
    }
}
