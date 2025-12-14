import SwiftUI

struct SmartLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize

    let onConfirm: (String) -> Void

    // Data sources
    @State private var allBookNames: [String] = []
    @State private var isLoadingBooks: Bool = true

    // Selection state
    @State private var bookQuery: String = ""
    @State private var filteredBooks: [String] = []
    @State private var selectedBookName: String? = nil
    @State private var loadedBook: Book? = nil

    @State private var chapter: String = ""
    @State private var startVerse: String = ""
    @State private var endVerse: String = ""

    // Focus
    @FocusState private var focusedField: Field?
    private enum Field { case book, chapter, start, end }

    // Async load
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var isLoadingBook: Bool = false
    @State private var loadError: Bool = false

    // Wheel pickers
    @State private var showChapterPicker: Bool = false
    @State private var showStartPicker: Bool = false
    @State private var showEndPicker: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if hSize == .regular {
                    // iPad / regular width: original single row layout
                    HStack(alignment: .top, spacing: 12) {
                        bookColumn
                            .frame(minWidth: 160)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        chapterColumn
                        startColumn
                        endColumn
                    }
                } else {
                    // iPhone / compact width: Book on first row, Chapter/Start/End on second row
                    VStack(spacing: 12) {
                        bookColumn
                        HStack(alignment: .top, spacing: 12) {
                            chapterColumn
                                .frame(maxWidth: .infinity, alignment: .leading)
                            startColumn
                                .frame(maxWidth: .infinity, alignment: .leading)
                            endColumn
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                // Status row (progress/error)
                HStack(spacing: 8) {
                    if isLoadingBooks {
                        ProgressView("Loading books…")
                    } else if isLoadingBook {
                        ProgressView("Loading \(selectedBookName ?? "")…")
                    } else if loadError {
                        Text("Couldn’t load book").foregroundStyle(.red)
                    } else {
                        Spacer(minLength: 0)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .navigationTitle("Insert Smart Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        guard let text = buildReferenceText() else { return }
                        onConfirm(text)
                        dismiss()
                    }
                    .disabled(!canInsert)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .task {
                isLoadingBooks = true
                let names = await BibleLibrary.shared.bookNames()
                isLoadingBooks = false
                allBookNames = names
                filterBooks(with: bookQuery)
                focusedField = .book
            }
            .sheet(isPresented: $showChapterPicker) {
                if let book = loadedBook {
                    WheelPickerSheet(
                        title: "Choose Chapter",
                        items: book.chapters.map { $0.number },
                        selection: Binding(
                            get: { Int(chapter) ?? (book.chapters.first?.number ?? 1) },
                            set: { newValue in
                                chapter = String(newValue)
                                clampChapterAndVerses()
                                selectAllOnNextFocus(.chapter)
                                showChapterPicker = false
                            }
                        )
                    )
                }
            }
            .sheet(isPresented: $showStartPicker) {
                if let ch = currentChapter() {
                    WheelPickerSheet(
                        title: "Choose Start Verse",
                        items: ch.verses.map { $0.number },
                        selection: Binding(
                            get: { Int(startVerse) ?? (ch.verses.first?.number ?? 1) },
                            set: { newValue in
                                startVerse = String(newValue)
                                clampChapterAndVerses()
                                selectAllOnNextFocus(.start)
                                showStartPicker = false
                            }
                        )
                    )
                }
            }
            .sheet(isPresented: $showEndPicker) {
                if let ch = currentChapter() {
                    WheelPickerSheet(
                        title: "Choose End Verse",
                        items: ch.verses.map { $0.number },
                        selection: Binding(
                            get: {
                                if let e = Int(endVerse), ch.verses.contains(where: { $0.number == e }) { return e }
                                if let s = Int(startVerse), ch.verses.contains(where: { $0.number == s }) { return s }
                                return ch.verses.first?.number ?? 1
                            },
                            set: { newValue in
                                endVerse = String(newValue)
                                clampChapterAndVerses()
                                selectAllOnNextFocus(.end)
                                showEndPicker = false
                            }
                        )
                    )
                }
            }
        }
        // Keep sheet size modest on iPhone
        .presentationDetents([.medium, .large])
    }

    // MARK: - Columns

    private var bookColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Book")
            VStack(alignment: .leading, spacing: 6) {
                TextField("Book", text: $bookQuery)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .book)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: bookQuery) { _, newValue in
                        filterBooks(with: newValue)
                        if let sel = selectedBookName, sel.caseInsensitiveCompare(newValue) != .orderedSame {
                            selectedBookName = nil
                            loadedBook = nil
                        }
                    }
                    .overlay(alignment: .trailing) {
                        if !bookQuery.isEmpty {
                            Button {
                                bookQuery = ""
                                filteredBooks = allBookNames.prefix(10).map { $0 }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                        }
                    }

                if focusedField == .book, !isLoadingBooks, !filteredBooks.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(filteredBooks.prefix(8), id: \.self) { name in
                                Button {
                                    pickBook(name)
                                    selectAllOnNextFocus(.chapter)
                                } label: {
                                    HStack {
                                        Text(name)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                    .zIndex(10)
                }
            }
        }
    }

    private var chapterColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Chapter")
            HStack(spacing: 6) {
                TextField("1", text: $chapter)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .chapter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .onChange(of: chapter) { _, _ in
                        clampChapterAndVerses()
                    }
                Button {
                    if loadedBook != nil { showChapterPicker = true }
                } label: {
                    Image(systemName: "chevron.down.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(loadedBook == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.blue))
                .disabled(loadedBook == nil)
            }
        }
    }

    private var startColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Start")
            HStack(spacing: 6) {
                TextField("1", text: $startVerse)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .start)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .onChange(of: startVerse) { _, _ in
                        clampChapterAndVerses()
                    }
                Button {
                    if loadedBook != nil, currentChapter() != nil { showStartPicker = true }
                } label: {
                    Image(systemName: "chevron.down.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(!(loadedBook != nil && currentChapter() != nil) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.blue))
                .disabled(!(loadedBook != nil && currentChapter() != nil))
            }
        }
    }

    private var endColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("End")
            HStack(spacing: 6) {
                TextField("—", text: $endVerse)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .end)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .onChange(of: endVerse) { _, _ in
                        clampChapterAndVerses()
                    }
                Button {
                    if loadedBook != nil, currentChapter() != nil { showEndPicker = true }
                } label: {
                    Image(systemName: "chevron.down.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(!(loadedBook != nil && currentChapter() != nil) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.blue))
                .disabled(!(loadedBook != nil && currentChapter() != nil))
            }
        }
    }

    // MARK: - UI helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(alignment: .leading)
    }

    // MARK: - Validation

    private var canInsert: Bool {
        guard let _ = selectedBookName ?? (bookQuery.isEmpty ? nil : bookQuery),
              let b = loadedBook else { return false }
        guard let chap = Int(chapter), chap >= 1, chap <= b.chapters.count else { return false }
        guard let ch = b.chapters.first(where: { $0.number == chap }) else { return false }
        guard let sv = Int(startVerse), !ch.verses.isEmpty,
              sv >= (ch.verses.first?.number ?? 1), sv <= (ch.verses.last?.number ?? 1) else { return false }
        if let ev = Int(endVerse), !endVerse.isEmpty {
            return ev >= sv && ev <= (ch.verses.last?.number ?? sv)
        }
        return true
    }

    private func buildReferenceText() -> String? {
        guard let book = selectedBookName ?? (bookQuery.isEmpty ? nil : bookQuery),
              let chap = Int(chapter), let sv = Int(startVerse) else { return nil }
        if let ev = Int(endVerse), !endVerse.isEmpty, ev >= sv {
            return "\(book) \(chap):\(sv)-\(ev)"
        }
        return "\(book) \(chap):\(sv)"
    }

    // MARK: - Book loading and filtering

    private func filterBooks(with q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            filteredBooks = allBookNames.prefix(10).map { $0 }
            return
        }
        let lower = trimmed.lowercased()
        var results: [String] = []
        var seen: Set<String> = []
        func add(_ name: String) {
            if !seen.contains(name.lowercased()) {
                results.append(name)
                seen.insert(name.lowercased())
            }
        }
        for n in allBookNames where n.lowercased().hasPrefix(lower) {
            add(n); if results.count == 10 { break }
        }
        if results.count < 10 {
            for n in allBookNames where n.lowercased().contains(lower) {
                add(n); if results.count == 10 { break }
            }
        }
        filteredBooks = results
    }

    private func pickBook(_ name: String) {
        bookQuery = name
        selectedBookName = name
        filteredBooks = []
        loadBook(named: name)
    }

    private func loadBook(named name: String) {
        loadTask?.cancel()
        loadError = false
        isLoadingBook = true
        loadTask = Task {
            if let b = try? await BibleLibrary.shared.loadBook(named: name) {
                await MainActor.run {
                    self.loadedBook = b
                    self.isLoadingBook = false
                    self.clampChapterAndVerses()
                }
            } else {
                await MainActor.run {
                    self.loadedBook = nil
                    self.isLoadingBook = false
                    self.loadError = true
                }
            }
        }
    }

    private func currentChapter() -> Chapter? {
        guard let b = loadedBook, let chap = Int(chapter) else { return nil }
        return b.chapters.first(where: { $0.number == chap })
    }

    private func clampChapterAndVerses() {
        guard let b = loadedBook else { return }

        // Determine valid chapter bounds
        let minChapter = b.chapters.first?.number ?? 1
        let maxChapter = b.chapters.last?.number ?? minChapter

        // Clamp chapter only if a numeric value was entered
        var resolvedChapter: Int? = nil
        if let chapInt = Int(chapter) {
            let clampedChap = min(max(chapInt, minChapter), maxChapter)
            if chapter != String(clampedChap) {
                chapter = String(clampedChap)
            }
            resolvedChapter = clampedChap
        }

        // If chapter isn't a valid number yet, don't prefill anything else
        guard let chapNumber = resolvedChapter,
              let ch = b.chapters.first(where: { $0.number == chapNumber }) else {
            return
        }

        // Verse bounds for the selected chapter
        let minV = ch.verses.first?.number ?? 1
        let maxV = ch.verses.last?.number ?? minV

        // Clamp start only if a numeric value was entered
        if let svInt = Int(startVerse) {
            let clampedSV = min(max(svInt, minV), maxV)
            if startVerse != String(clampedSV) {
                startVerse = String(clampedSV)
            }
        }

        // Clamp end only to chapter bounds; do NOT auto-raise it to start.
        if let evInt = Int(endVerse) {
            let clampedEV = min(max(evInt, minV), maxV)
            if endVerse != String(clampedEV) {
                endVerse = String(clampedEV)
            }
        }
    }

    // MARK: - Validity helpers and select-all behavior

    private func selectAllOnNextFocus(_ field: Field) {
        DispatchQueue.main.async { focusedField = field }
    }
}

// Simple wheel picker shell used for Chapter/Verse pickers
private struct WheelPickerSheet<T: Hashable & Identifiable & CustomStringConvertible>: View {
    let title: String
    let items: [T]
    @Binding var selection: T

    init(title: String, items: [Int], selection: Binding<Int>) where T == IntWrapper {
        self.title = title
        self.items = items.map { IntWrapper(value: $0) }
        self._selection = Binding(
            get: { IntWrapper(value: selection.wrappedValue) },
            set: { selection.wrappedValue = $0.value }
        )
    }

    init(title: String, items: [T], selection: Binding<T>) {
        self.title = title
        self.items = items
        self._selection = selection
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $selection) {
                    ForEach(items) { item in
                        Text(item.description).tag(item)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

private struct IntWrapper: Hashable, Identifiable, CustomStringConvertible {
    let value: Int
    var id: Int { value }
    var description: String { "\(value)" }
}
