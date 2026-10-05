// ScripturePickerView.swift
import SwiftUI

struct ScripturePickerView: View {
    @Environment(\.dismiss) private var dismiss

    // Initial selection (optional)
    let initialBook: String?
    let initialChapter: Int?
    let initialVerse: Int?

    // Called when user taps Done
    let onConfirm: (String, Int, Int) -> Void

    // Data
    @State private var allBookNames: [String] = []
    @State private var isLoadingBooks: Bool = true
    @State private var isLoadingBook: Bool = false
    @State private var loadError: Bool = false

    // Selection state
    @State private var bookSelection: String = ""   // non-optional for UI
    @State private var loadedBook: Book? = nil
    @State private var selectedChapter: Int = 1
    @State private var selectedVerse: Int = 1
    @State private var previewText: String = ""
    @State private var bookSearchText: String = ""

    // Async book load cancellation
    @State private var loadTask: Task<Void, Never>? = nil

    // Prevent double-commit (Done + onDisappear)
    @State private var didConfirm: Bool = false

    // Focused picker (shown in a sheet)
    private enum ActivePicker: Identifiable {
        case book, chapter, verse
        var id: Int { hashValue }
        var title: String {
            switch self {
            case .book: return "Choose Book"
            case .chapter: return "Choose Chapter"
            case .verse: return "Choose Verse"
            }
        }
    }
    @State private var activePicker: ActivePicker? = nil

    var body: some View {
        Form {
            Section {
                if isLoadingBooks {
                    HStack { Spacer(); ProgressView("Loading books…"); Spacer() }
                } else if allBookNames.isEmpty {
                    LabeledContent("Status") { Text("No books found").foregroundStyle(.red) }
                } else {
                    // Three rows that open a focused modern wheel
                    selectionRow(
                        label: "Book",
                        value: loadedBook?.name ?? (bookSelection.isEmpty ? "Choose…" : bookSelection),
                        enabled: true
                    ) { activePicker = .book }

                    selectionRow(
                        label: "Chapter",
                        value: chapterLabel(),
                        enabled: loadedBook != nil
                    ) { if loadedBook != nil { activePicker = .chapter } }

                    selectionRow(
                        label: "Verse",
                        value: verseLabel(),
                        enabled: (loadedBook != nil && currentChapter() != nil)
                    ) { if loadedBook != nil, currentChapter() != nil { activePicker = .verse } }
                }

                if isLoadingBook {
                    HStack { Spacer(); ProgressView("Loading \(bookSelection)…"); Spacer() }
                }

                if loadError {
                    LabeledContent("Status") { Text("Couldn’t load book").foregroundStyle(.red) }
                }
            } header: {
                Text("Scripture")
            } footer: {
                Text("Tap Book, Chapter, or Verse to choose, then scroll or tap an option.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let book = loadedBook, !previewText.isEmpty {
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("“\(previewText)”")
                            .font(.body)
                        Text("\(book.name) \(selectedChapter):\(selectedVerse)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    guard let book = loadedBook else { return }
                    didConfirm = true
                    onConfirm(book.name, selectedChapter, selectedVerse)
                    dismiss()
                }
                .disabled(loadedBook == nil)
            }
        }
        .onAppear {
            Task {
                // Load book names
                isLoadingBooks = true
                let names = await BibleRepository.shared.bookNames()
                isLoadingBooks = false
                allBookNames = names

                guard !names.isEmpty else { return }

                // Seed initial book selection
                let initial = initialBook.flatMap { names.contains($0) ? $0 : nil } ?? names.first!
                bookSelection = initial

                // Load the initial book and seed chapter/verse
                await loadBook(named: initial, seedChapter: initialChapter, seedVerse: initialVerse)
            }
        }
        .onDisappear {
            // If user navigated back without tapping Done, commit if we have a full selection
            if !didConfirm, let book = loadedBook {
                onConfirm(book.name, selectedChapter, selectedVerse)
            }
            loadTask?.cancel()
        }
        .sheet(item: $activePicker) { which in
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    switch which {
                    case .book:
                        List(filteredBookNames, id: \.self) { bookName in
                            Button {
                                bookSelection = bookName
                                UISelectionFeedbackGenerator().selectionChanged()
                                loadTask?.cancel()
                                loadTask = Task {
                                    await loadBook(named: bookName, seedChapter: nil, seedVerse: nil)
                                    guard !Task.isCancelled, loadedBook?.name == bookName else { return }
                                    activePicker = nil
                                }
                            } label: {
                                HStack {
                                    Text(bookName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if bookName == bookSelection {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                        .searchable(text: $bookSearchText, prompt: "Search books")

                    case .chapter:
                        if let book = loadedBook {
                            List(book.chapters, id: \.number) { chapter in
                                Button {
                                    selectedChapter = chapter.number
                                    let first = chapter.verses.first?.number ?? 1
                                    let last = chapter.verses.last?.number ?? first
                                    selectedVerse = min(max(selectedVerse, first), last)
                                    updatePreviewText()
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    activePicker = nil
                                } label: {
                                    selectionOptionRow(
                                        title: "Chapter \(chapter.number)",
                                        isSelected: chapter.number == selectedChapter
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .listStyle(.plain)
                        } else {
                            ContentUnavailableView("Choose a book first", systemImage: "book")
                                .padding()
                        }

                    case .verse:
                        if let ch = currentChapter() {
                            List(ch.verses) { verse in
                                Button {
                                    selectedVerse = verse.number
                                    updatePreviewText()
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    activePicker = nil
                                } label: {
                                    selectionOptionRow(
                                        title: "Verse \(verse.number)",
                                        isSelected: verse.number == selectedVerse
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .listStyle(.plain)
                        } else {
                            ContentUnavailableView("Choose a chapter first", systemImage: "text.book.closed")
                                .padding()
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle(which.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { activePicker = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { activePicker = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - UI helpers

    private func selectionRow(label: String, value: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(enabled ? .primary : .tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.vertical, 2)
    }

    private var navigationTitle: String {
        if let book = loadedBook {
            return "\(book.name) \(selectedChapter)"
        } else if !bookSelection.isEmpty {
            return bookSelection
        } else {
            return "Select Scripture"
        }
    }

    private var filteredBookNames: [String] {
        let query = bookSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allBookNames }
        return allBookNames.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private func selectionOptionRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }

    private func currentChapter() -> Chapter? {
        guard let b = loadedBook else { return nil }
        return b.chapters.first(where: { $0.number == selectedChapter })
    }

    private func chapterLabel() -> String {
        loadedBook == nil ? "—" : "\(selectedChapter)"
    }

    private func verseLabel() -> String {
        guard let ch = currentChapter() else { return "—" }
        return ch.verses.isEmpty ? "—" : "\(selectedVerse)"
    }

    // MARK: - Loading & Preview

    @MainActor
    private func loadBook(named name: String, seedChapter: Int?, seedVerse: Int?) async {
        isLoadingBook = true
        loadError = false

        let prevChapter = selectedChapter
        let prevVerse = selectedVerse

        if let b = await BibleRepository.shared.loadBook(named: name) {
                guard !Task.isCancelled, bookSelection == name else { return }
                loadedBook = b

                // Decide chapter:
                // 1) Use seed if valid
                // 2) Else preserve previous if valid in this book
                // 3) Else clamp to last valid chapter (not always 1)
                let chapterNum: Int = {
                    if let ic = seedChapter, b.chapters.contains(where: { $0.number == ic }) {
                        return ic
                    }
                    if b.chapters.contains(where: { $0.number == prevChapter }) {
                        return prevChapter
                    }
                    return b.chapters.last?.number ?? 1
                }()
                selectedChapter = chapterNum

                // Decide verse:
                if let ch = b.chapters.first(where: { $0.number == chapterNum }) {
                    let verseNum: Int = {
                        if let iv = seedVerse, ch.verses.contains(where: { $0.number == iv }) {
                            return iv
                        }
                        let first = ch.verses.first?.number ?? 1
                        let last = ch.verses.last?.number ?? first
                        if prevChapter == chapterNum {
                            return min(max(prevVerse, first), last)
                        } else {
                            return first
                        }
                    }()
                    selectedVerse = verseNum
                    if let v = ch.verses.first(where: { $0.number == verseNum }) {
                        previewText = v.text
                    } else {
                        previewText = ""
                    }
                } else {
                    selectedVerse = 1
                    previewText = ""
                }
        } else if !Task.isCancelled, bookSelection == name {
            loadedBook = nil
            loadError = true
        }
        if bookSelection == name {
            isLoadingBook = false
        }
    }

    private func updatePreviewText() {
        guard let b = loadedBook,
              let chapter = b.chapters.first(where: { $0.number == selectedChapter }),
              let verse = chapter.verses.first(where: { $0.number == selectedVerse }) else {
            previewText = ""
            return
        }
        previewText = verse.text
    }
}
