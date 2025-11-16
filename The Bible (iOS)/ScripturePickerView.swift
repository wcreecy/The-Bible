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

    // Selection state
    @State private var selectedBookName: String? = nil
    @State private var loadedBook: Book? = nil
    @State private var selectedChapter: Int? = nil
    @State private var selectedVerse: Int? = nil
    @State private var previewText: String = ""

    // Data/loading state
    @State private var allBookNames: [String] = []
    @State private var isLoadingBooks: Bool = true
    @State private var isLoadingBook: Bool = false
    @State private var loadError: Bool = false

    // Book picker sheet
    @State private var showBookPicker: Bool = false
    @State private var bookSearchText: String = ""

    var body: some View {
        Form {
            Section {
                Button {
                    showBookPicker = true
                } label: {
                    HStack {
                        Text("Book")
                        Spacer()
                        if isLoadingBooks {
                            ProgressView()
                        } else if let name = selectedBookName, !name.isEmpty {
                            Text(name).foregroundStyle(.secondary)
                        } else {
                            Text("Choose…").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingBooks)

                Picker("Chapter", selection: Binding<Int?>(
                    get: { selectedChapter },
                    set: { newValue in
                        selectedChapter = newValue
                        // Reset verse and preview when chapter changes
                        selectedVerse = nil
                        previewText = ""
                    }
                )) {
                    if let book = loadedBook {
                        ForEach(book.chapters, id: \.number) { ch in
                            Text("\(ch.number)").tag(Optional(ch.number))
                        }
                    }
                }
                .disabled(loadedBook == nil)
                .pickerStyle(.navigationLink)

                Picker("Verse", selection: Binding<Int?>(
                    get: { selectedVerse },
                    set: { newValue in
                        selectedVerse = newValue
                        updatePreviewText()
                    }
                )) {
                    if let book = loadedBook, let chapterNum = selectedChapter,
                       let chapter = book.chapters.first(where: { $0.number == chapterNum }) {
                        ForEach(chapter.verses, id: \.number) { v in
                            Text("\(v.number)").tag(Optional(v.number))
                        }
                    }
                }
                .disabled(loadedBook == nil || selectedChapter == nil)
                .pickerStyle(.navigationLink)

                if isLoadingBook {
                    HStack {
                        Spacer()
                        ProgressView("Loading \(selectedBookName ?? "book")…")
                        Spacer()
                    }
                }

                if loadError {
                    LabeledContent("Status") {
                        Text("Couldn’t load book").foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Scripture")
            } footer: {
                Text("Choose the book, chapter, and verse for the pinned verse widget.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let book = loadedBook, let chapter = selectedChapter, let verse = selectedVerse, !previewText.isEmpty {
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("“\(previewText)”")
                            .font(.body)
                        Text("\(book.name) \(chapter):\(verse)")
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
                    if let b = selectedBookName, let c = selectedChapter, let v = selectedVerse {
                        onConfirm(b, c, v)
                        dismiss()
                    }
                }
                .disabled(selectedBookName == nil || selectedChapter == nil || selectedVerse == nil)
            }
        }
        .onAppear {
            Task {
                // Load book names
                isLoadingBooks = true
                let names = await BibleLibrary.shared.bookNames()
                allBookNames = names
                isLoadingBooks = false

                // Seed initial selection
                if let b = initialBook, names.contains(b) {
                    await setBook(b, seedChapter: initialChapter, seedVerse: initialVerse)
                }
            }
        }
        .sheet(isPresented: $showBookPicker) {
            NavigationStack {
                BookPickerSheet(
                    allBookNames: allBookNames,
                    searchText: $bookSearchText,
                    currentSelection: selectedBookName,
                    onSelect: { name in
                        showBookPicker = false
                        Task { await setBook(name, seedChapter: nil, seedVerse: nil) }
                    }
                )
                .navigationTitle("Choose Book")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showBookPicker = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var navigationTitle: String {
        if let b = selectedBookName, let c = selectedChapter {
            return "\(b) \(c)"
        } else if let b = selectedBookName {
            return b
        } else {
            return "Select Scripture"
        }
    }

    // Load a book by name, update state, and optionally seed chapter/verse
    @MainActor
    private func setBook(_ name: String, seedChapter: Int?, seedVerse: Int?) async {
        selectedBookName = name
        selectedChapter = nil
        selectedVerse = nil
        previewText = ""
        loadError = false
        isLoadingBook = true
        do {
            if let b = try await BibleLibrary.shared.loadBook(named: name) {
                loadedBook = b
                // Seed chapter/verse if provided and valid
                if let ic = seedChapter, b.chapters.contains(where: { $0.number == ic }) {
                    selectedChapter = ic
                    if let iv = seedVerse,
                       let ch = b.chapters.first(where: { $0.number == ic }),
                       ch.verses.contains(where: { $0.number == iv }) {
                        selectedVerse = iv
                        if let v = ch.verses.first(where: { $0.number == iv }) {
                            previewText = v.text
                        }
                    }
                }
            } else {
                loadedBook = nil
                loadError = true
            }
        } catch {
            loadedBook = nil
            loadError = true
        }
        isLoadingBook = false
    }

    private func updatePreviewText() {
        guard let b = loadedBook,
              let c = selectedChapter,
              let v = selectedVerse,
              let chapter = b.chapters.first(where: { $0.number == c }),
              let verse = chapter.verses.first(where: { $0.number == v }) else {
            previewText = ""
            return
        }
        previewText = verse.text
    }
}

// MARK: - Book Picker Sheet

private struct BookPickerSheet: View {
    let allBookNames: [String]
    @Binding var searchText: String
    let currentSelection: String?
    let onSelect: (String) -> Void

    private var filtered: [String] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return allBookNames }
        return allBookNames.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            ForEach(filtered, id: \.self) { (name: String) in
                Button {
                    onSelect(name)
                } label: {
                    HStack {
                        Text(name)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if name == currentSelection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if allBookNames.isEmpty {
                ProgressView("Loading books…")
            } else if filtered.isEmpty {
                ContentUnavailableView("No matches", systemImage: "text.magnifyingglass")
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search books")
    }
}
