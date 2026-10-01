import SwiftData
import SwiftUI

enum VerseHighlightColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: String { rawValue }

    var name: LocalizedStringResource {
        switch self {
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .pink: "Pink"
        case .purple: "Purple"
        }
    }

    var color: Color {
        switch self {
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .pink: .pink
        case .purple: .purple
        }
    }
}

@MainActor
struct VerseNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let verse: VerseActionReference
    let existingNote: VerseNote?

    @State private var noteText: String
    @State private var selectedColor: VerseHighlightColor?
    @State private var persistenceFailure: PersistenceFailure?

    init(verse: VerseActionReference, existingNote: VerseNote?) {
        self.verse = verse
        self.existingNote = existingNote
        _noteText = State(initialValue: existingNote?.content ?? "")
        _selectedColor = State(
            initialValue: existingNote.flatMap { VerseHighlightColor(rawValue: $0.highlightColor) }
        )
    }

    var body: some View {
        Form {
            VerseNotePassageSection(reference: verse)

            Section("Highlight") {
                HighlightColorPicker(selection: $selectedColor)
            }

            Section("Private Note") {
                TextEditor(text: $noteText)
                    .frame(minHeight: 140)
                    .accessibilityLabel("Private note")
            }

            if existingNote != nil {
                Section {
                    Button("Remove Note & Highlight", role: .destructive, action: deleteEntry)
                }
            }
        }
        .navigationTitle(existingNote == nil ? "Add Note & Highlight" : "Edit Note & Highlight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(existingNote == nil && trimmedNote.isEmpty && selectedColor == nil)
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    private var trimmedNote: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if let existingNote, trimmedNote.isEmpty, selectedColor == nil {
                    modelContext.delete(existingNote)
                    try modelContext.save()
                    return
                }

                let note = existingNote ?? VerseNote(
                    bookName: verse.bookName,
                    chapterNumber: verse.chapterNumber,
                    verseNumber: verse.verseNumber,
                    verseText: verse.verseText
                )
                note.content = trimmedNote
                note.highlightColor = selectedColor?.rawValue ?? ""
                note.updatedAt = Date()
                if existingNote == nil {
                    modelContext.insert(note)
                }
                try modelContext.save()
            },
            onSuccess: {
                Haptics.success()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func deleteEntry() {
        guard let existingNote else { return }
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                modelContext.delete(existingNote)
                try modelContext.save()
            },
            onSuccess: {
                Haptics.selection()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }
}

private struct VerseNotePassageSection: View {
    let reference: VerseActionReference

    var body: some View {
        Section {
            Text(reference.verseText)
            Text("\(reference.bookName) \(reference.chapterNumber):\(reference.verseNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HighlightColorPicker: View {
    @Binding var selection: VerseHighlightColor?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(VerseHighlightColor.allCases) { highlight in
                Button {
                    selection = highlight
                } label: {
                    Circle()
                        .fill(highlight.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selection == highlight {
                                Circle().stroke(.primary, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(highlight.name))
                .accessibilityAddTraits(selection == highlight ? .isSelected : [])
            }

            Button {
                selection = nil
            } label: {
                Circle()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        if selection == nil {
                            Circle().stroke(.primary, lineWidth: 3)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear highlight")
            .accessibilityAddTraits(selection == nil ? .isSelected : [])
        }
        .frame(maxWidth: .infinity)
    }
}

@MainActor
struct NotesAndHighlightsView: View {
    @Query(sort: \VerseNote.updatedAt, order: .reverse) private var notes: [VerseNote]
    @State private var searchText = ""
    @State private var selectedNote: VerseNote?

    var body: some View {
        List {
            if visibleNotes.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Notes or Highlights" : "No Results",
                    systemImage: searchText.isEmpty ? "highlighter" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                        ? "Press and hold a verse to add a private note or highlight."
                        : "Try searching for a reference, verse, or note.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleNotes) { note in
                    Button {
                        selectedNote = note
                    } label: {
                        NoteHighlightRow(
                            reference: "\(note.bookName) \(note.chapterNumber):\(note.verseNumber)",
                            verseText: note.verseText,
                            noteText: note.content,
                            highlight: VerseHighlightColor(rawValue: note.highlightColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button("Open", systemImage: "book") {
                            open(note)
                        }
                        .tint(.accentColor)
                    }
                }
                .onDelete(perform: delete)
                .listRowBackground(HeroCardListRowBackground())
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Notes & Highlights")
        .searchable(text: $searchText, prompt: "Search notes and verses")
        .sheet(item: $selectedNote) { note in
            NavigationStack {
                VerseNoteEditorView(
                    verse: VerseActionReference(
                        bookName: note.bookName,
                        chapterNumber: note.chapterNumber,
                        verseNumber: note.verseNumber,
                        verseText: note.verseText
                    ),
                    existingNote: note
                )
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Open in Bible", systemImage: "book") {
                            selectedNote = nil
                            open(note)
                        }
                    }
                }
            }
        }
    }

    private var visibleNotes: [VerseNote] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.bookName.localizedCaseInsensitiveContains(searchText) ||
            $0.verseText.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            "\($0.chapterNumber):\($0.verseNumber)".localizedCaseInsensitiveContains(searchText)
        }
    }

    private func open(_ note: VerseNote) {
        NotificationCenter.default.post(
            name: .openBibleReference,
            object: nil,
            userInfo: [
                "book": note.bookName,
                "chapter": note.chapterNumber,
                "verse": note.verseNumber
            ]
        )
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleNotes[index])
        }
        try? modelContext.save()
    }

    @Environment(\.modelContext) private var modelContext
}

private struct NoteHighlightRow: View {
    let reference: String
    let verseText: String
    let noteText: String
    let highlight: VerseHighlightColor?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(highlight?.color ?? .clear)
                .frame(width: 6)
                .overlay {
                    if highlight == nil {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(reference)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(verseText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if !noteText.isEmpty {
                    Label(noteText, systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
