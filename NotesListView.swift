import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var notes: [VerseNote]

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    ContentUnavailableView {
                        Label("No Notes", systemImage: "note.text")
                    }
                } else {
                    List {
                        ForEach(notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                            NavigationLink(destination: destinationView(for: note)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(previewText(for: note))
                                        .lineLimit(3)
                                        .font(.body)
                                    HStack {
                                        Text(reference(for: note))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(note.createdAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func previewText(for note: VerseNote) -> String {
        let lines = note.content.components(separatedBy: .newlines)
        return lines.prefix(3).joined(separator: "\n")
    }

    private func reference(for note: VerseNote) -> String {
        "\(note.bookName) \(note.chapterNumber):\(note.verseNumber)"
    }

    @ViewBuilder
    private func destinationView(for note: VerseNote) -> some View {
        if let book = BibleData.books.first(where: { $0.name == note.bookName }),
           let chapter = book.chapters.first(where: { $0.number == note.chapterNumber }) {
            ReadingView(book: book, chapter: chapter, startVerse: note.verseNumber)
        } else {
            Text("Unable to open verse")
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        let sorted = notes.sorted(by: { $0.createdAt > $1.createdAt })
        for index in offsets {
            let note = sorted[index]
            modelContext.delete(note)
        }
        try? modelContext.save()
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: [ReaderSettings.self, ReadingProgress.self, Favorite.self, Bookmark.self, VerseNote.self], inMemory: true)
}

