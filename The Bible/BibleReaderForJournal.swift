import SwiftUI

struct BibleReaderForJournal: View {
    @State private var searchText: String = ""
    @State private var currentBookIndex: Int = 0
    @State private var currentChapterIndex: Int = 0
    @State private var targetVerse: Int? = nil

    // Optional callbacks for long-press actions on verses
    var onInsertText: ((String, Int, Int, String) -> Void)? = nil
    var onInsertLink: ((String, Int, Int) -> Void)? = nil
    var onFavorite: ((String, Int, Int, String) -> Void)? = nil

    private var books: [Book] { BibleData.books }
    private var currentBook: Book { books[safe: currentBookIndex] ?? books.first! }
    private var currentChapter: Chapter {
        currentBook.chapters[safe: currentChapterIndex] ?? currentBook.chapters.first!
    }

    // Scroll positioning
    @State private var topVisibleVerseID: String? = nil
    @State private var highlightedVerse: Int? = nil

    // Popover state for pickers
    @State private var showBookPicker: Bool = false
    @State private var showChapterPicker: Bool = false

    // Inline menu state (new)
    @State private var menuVerse: Int? = nil
    @State private var selectedVerse: Int? = nil

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: Search only
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Go to (e.g. Gen 1:7)", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.go)
                        .onSubmit { goToSearch() }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Row 2: Smaller Book and Chapter controls (buttons -> popovers)
            HStack(spacing: 8) {
                Button {
                    showBookPicker = true
                } label: {
                    SmallMenuLabel(systemImage: "book", text: currentBook.name)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showBookPicker, arrowEdge: .top) {
                    #if os(iOS)
                    if #available(iOS 17.0, *) {
                        // Keep popover style in compact instead of adapting to a full sheet
                        BookPickerPopover(
                            books: books,
                            currentIndex: currentBookIndex,
                            onSelect: { idx in
                                currentBookIndex = idx
                                currentChapterIndex = 0
                                targetVerse = nil
                                showBookPicker = false
                                scrollToTop()
                            },
                            onCancel: { showBookPicker = false }
                        )
                        .presentationCompactAdaptation(.popover)
                    } else {
                        // iOS 16 fallback: shorter sheet by default (popover adapts to sheet)
                        BookPickerPopover(
                            books: books,
                            currentIndex: currentBookIndex,
                            onSelect: { idx in
                                currentBookIndex = idx
                                currentChapterIndex = 0
                                targetVerse = nil
                                showBookPicker = false
                                scrollToTop()
                            },
                            onCancel: { showBookPicker = false }
                        )
                        .presentationDetents([.fraction(0.5), .large])
                        .presentationDragIndicator(.visible)
                    }
                    #else
                    BookPickerPopover(
                        books: books,
                        currentIndex: currentBookIndex,
                        onSelect: { idx in
                            currentBookIndex = idx
                            currentChapterIndex = 0
                            targetVerse = nil
                            showBookPicker = false
                            scrollToTop()
                        },
                        onCancel: { showBookPicker = false }
                    )
                    #endif
                }

                Button {
                    showChapterPicker = true
                } label: {
                    SmallMenuLabel(systemImage: "list.number", text: "Ch \(currentChapter.number)")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showChapterPicker, arrowEdge: .top) {
                    #if os(iOS)
                    if #available(iOS 17.0, *) {
                        ChapterPickerPopover(
                            chapters: currentBook.chapters,
                            currentIndex: currentChapterIndex,
                            onSelect: { idx in
                                currentChapterIndex = idx
                                targetVerse = nil
                                showChapterPicker = false
                                scrollToTop()
                            },
                            onCancel: { showChapterPicker = false }
                        )
                        .presentationCompactAdaptation(.popover)
                    } else {
                        ChapterPickerPopover(
                            chapters: currentBook.chapters,
                            currentIndex: currentChapterIndex,
                            onSelect: { idx in
                                currentChapterIndex = idx
                                targetVerse = nil
                                showChapterPicker = false
                                scrollToTop()
                            },
                            onCancel: { showChapterPicker = false }
                        )
                        .presentationDetents([.fraction(0.5), .large])
                        .presentationDragIndicator(.visible)
                    }
                    #else
                    ChapterPickerPopover(
                        chapters: currentBook.chapters,
                        currentIndex: currentChapterIndex,
                        onSelect: { idx in
                            currentChapterIndex = idx
                            targetVerse = nil
                            showChapterPicker = false
                            scrollToTop()
                        },
                        onCancel: { showChapterPicker = false }
                    )
                    #endif
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            Divider()

            // Reader
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(currentChapter.verses) { verse in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verse.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(currentBook.name) \(currentChapter.number):\(verse.number)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((highlightedVerse == verse.number || selectedVerse == verse.number) ? Color.yellow.opacity(0.25) : Color.clear)
                        .id(rowID(for: verse.number))
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.5) {
                            #if canImport(UIKit)
                            let gen = UIImpactFeedbackGenerator(style: .heavy)
                            gen.impactOccurred()
                            #endif
                            menuVerse = verse.number
                        }
                        .onTapGesture {
                            selectedVerse = verse.number
                            if menuVerse != nil { menuVerse = nil }
                        }

                        if menuVerse == verse.number {
                            HStack(spacing: 24) {
                                Button {
                                    onInsertText?(currentBook.name, currentChapter.number, verse.number, verse.text)
                                    withAnimation(.easeInOut) { menuVerse = nil }
                                } label: {
                                    Image(systemName: "doc.text")
                                }
                                .foregroundStyle(.blue)

                                Button {
                                    onInsertLink?(currentBook.name, currentChapter.number, verse.number)
                                    withAnimation(.easeInOut) { menuVerse = nil }
                                } label: {
                                    Image(systemName: "link")
                                }
                                .foregroundStyle(.purple)

                                Button {
                                    onFavorite?(currentBook.name, currentChapter.number, verse.number, verse.text)
                                    withAnimation(.easeInOut) { menuVerse = nil }
                                } label: {
                                    Image(systemName: "heart")
                                }
                                .foregroundStyle(.red)
                            }
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                            .transition(.opacity)
                        }

                        if verse.number != currentChapter.verses.count {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 8)
                .scrollTargetLayout()
                .onTapGesture {
                    if menuVerse != nil { menuVerse = nil }
                }
            }
            .scrollPosition(id: $topVisibleVerseID, anchor: .top)
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        if abs(horizontal) > abs(vertical) && abs(horizontal) > 40 {
                            if horizontal < 0 {
                                nextChapter()
                            } else {
                                previousChapter()
                            }
                        }
                    }
            )
            .onAppear {
                // default to Genesis 1
                currentBookIndex = 0
                currentChapterIndex = 0
                scrollToTop()
            }
        }
    }

    private func goToSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Try to parse "Book Chap:Verse"
        let parts = trimmed.components(separatedBy: ":")
        let left = parts.first ?? trimmed
        let right = parts.count > 1 ? parts[1] : nil

        let leftTokens = left.split(separator: " ").map(String.init)
        guard !leftTokens.isEmpty else { return }

        var chapterNum: Int? = nil
        var bookNameCandidate = ""
        if let last = leftTokens.last, let chap = Int(last) {
            chapterNum = chap
            bookNameCandidate = leftTokens.dropLast().joined(separator: " ")
        } else {
            chapterNum = 1
            bookNameCandidate = leftTokens.joined(separator: " ")
        }

        if let idx = BibleData.books.firstIndex(where: { $0.name.compare(bookNameCandidate, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            currentBookIndex = idx
        } else if let resolved = resolveBookName(bookNameCandidate),
                  let idx = BibleData.books.firstIndex(where: { $0.name == resolved }) {
            currentBookIndex = idx
        } else {
            return
        }

        let book = books[currentBookIndex]
        let clampedChapter = min(max(1, chapterNum ?? 1), book.chapters.count)
        currentChapterIndex = clampedChapter - 1

        if let r = right, let v = Int(r) {
            let versesCount = currentChapter.verses.count
            let clampedVerse = min(max(1, v), versesCount)
            targetVerse = clampedVerse
            scrollToVerse(clampedVerse, highlight: true)
        } else {
            targetVerse = nil
            scrollToTop()
        }
    }

    private func resolveBookName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = BibleData.books.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return direct.name
        }
        let collapsed = trimmed.replacingOccurrences(of: " ", with: "")
        if let match = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match.name
        }
        let probe = "\(trimmed) 1:1"
        let attributed = BibleReferenceLinker.linkify(probe)
        let refs = ScriptureRefExtractor.refs(in: attributed)
        return refs.first?.bookName
    }

    private func nextChapter() {
        let book = currentBook
        if currentChapterIndex + 1 < book.chapters.count {
            currentChapterIndex += 1
            targetVerse = 1
            scrollToTop()
            return
        }
        if currentBookIndex + 1 < books.count {
            currentBookIndex += 1
            currentChapterIndex = 0
            targetVerse = 1
            scrollToTop()
        }
    }

    private func previousChapter() {
        if currentChapterIndex - 1 >= 0 {
            currentChapterIndex -= 1
            targetVerse = 1
            scrollToTop()
            return
        }
        if currentBookIndex - 1 >= 0 {
            currentBookIndex -= 1
            let newBook = books[currentBookIndex]
            currentChapterIndex = max(0, newBook.chapters.count - 1)
            targetVerse = 1
            scrollToTop()
        }
    }

    private func rowID(for verseNumber: Int) -> String {
        "\(currentBook.name)-\(currentChapter.number)-\(verseNumber)"
    }

    private func scrollToTop() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                topVisibleVerseID = rowID(for: 1)
            }
            highlightedVerse = nil
            menuVerse = nil
            selectedVerse = nil
        }
    }

    private func scrollToVerse(_ verse: Int, highlight: Bool) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                topVisibleVerseID = rowID(for: verse)
            }
            if highlight {
                highlightedVerse = verse
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { highlightedVerse = nil }
                }
            }
            menuVerse = nil
            selectedVerse = nil
        }
    }
}

// Compact, professional-looking menu label for Book/Chapter controls
private struct SmallMenuLabel: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
            Image(systemName: "chevron.down")
                .imageScale(.small)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// A simple row view to keep the Button label small and type-checkable
private struct BookRowView: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            Spacer()
            if isSelected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                    Text("Selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.18),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// Popover content for selecting a Book (modernized styling)
private struct BookPickerPopover: View {
    let books: [Book]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onCancel: () -> Void

    @State private var query: String = ""

    private var filteredIndices: [Int] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(books.indices)
        }
        let q = trimmed.lowercased()
        var result: [Int] = []
        result.reserveCapacity(books.count)
        for (idx, book) in books.enumerated() {
            if book.name.lowercased().contains(q) {
                result.append(idx)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredIndices, id: \.self) { idx in
                        Button {
                            onSelect(idx)
                        } label: {
                            BookRowView(
                                title: books[idx].name,
                                isSelected: idx == currentIndex
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .padding(16)
            }
            // Fill the available height in sheet/popover so content sits at the top cleanly
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onCancel() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search books")
        }
    }
}

// Popover content for selecting a Chapter (grid of chips)
private struct ChapterPickerPopover: View {
    let chapters: [Chapter]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onCancel: () -> Void

    // Adaptive grid: more columns on wider popover
    private var columns: [GridItem] {
        // Use adaptive sizing to fit nicely across iPhone/iPad popover sizes
        [GridItem(.adaptive(minimum: 44, maximum: 72), spacing: 10)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(chapters.indices, id: \.self) { idx in
                        let isSelected = (idx == currentIndex)
                        Button {
                            onSelect(idx)
                        } label: {
                            Text("\(chapters[idx].number)")
                                .font(.headline)
                                .foregroundStyle(isSelected ? .white : .primary)
                                .frame(width: 56, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
                                )
                                .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 6 : 3, x: 0, y: isSelected ? 3 : 2)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .padding(16)
            }
            // Fill the available height in sheet/popover so content sits at the top cleanly
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onCancel() }
                }
            }
        }
    }
}

// Convenience safe index
private extension Array {
    subscript(safe idx: Index) -> Element? {
        indices.contains(idx) ? self[idx] : nil
    }
}
