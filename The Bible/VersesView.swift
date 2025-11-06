import SwiftUI
import SwiftData
import UIKit

struct VersesView: View {
    let book: Book
    let chapter: Chapter
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Query private var favorites: [Favorite]
    @Query private var bookmarks: [Bookmark]
    @Query private var notes: [VerseNote]

    @State private var showNoteSheet: Bool = false
    @State private var noteDraft: String = ""

    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var toastSymbol: String = "checkmark.circle.fill"
    @State private var toastTint: Color = .blue

    @State private var previewVerse: Verse? = nil

    @State private var navToReader: Bool = false
    @State private var navStartVerse: Int = 1

    var body: some View {
        List {
            ForEach(chapter.verses) { verse in
                NavigationLink(destination: ReadingView(book: book, chapter: chapter, startVerse: verse.number)
                    .id("\(book.name)-\(chapter.number)-\(verse.number)")) {
                    HStack(spacing: 0) {
                        Text("Verse \(verse.number)")
                        Text(" of \(chapter.verses.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    previewVerse = verse
                }
            }
        }
        .sheet(item: $previewVerse) { verse in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(book.name) \(chapter.number):\(verse.number)")
                            .font(.title3).bold()
                        Text(verse.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                }
                .navigationTitle("Verse Preview")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { previewVerse = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Open") {
                            navStartVerse = verse.number
                            previewVerse = nil
                            if let book = BibleData.books.first(where: { $0.name == self.book.name }), let chapter = book.chapters.first(where: { $0.number == self.chapter.number }) {
                                coordinator.push(.reader(book: book, chapter: chapter, startVerse: verse.number))
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        // Copy
                        Button {
                            let share = "\"\(verse.text)\" — \(book.name) \(chapter.number):\(verse.number)"
                            UIPasteboard.general.string = share
                            toastSymbol = "doc.on.doc"
                            toastTint = .blue
                            toastText = "Copied to Clipboard"
                            withAnimation(.spring()) { showToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeOut) { showToast = false }
                            }
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }

                        // Share
                        ShareLink(item: "\"\(verse.text)\" — \(book.name) \(chapter.number):\(verse.number)") {
                            Image(systemName: "square.and.arrow.up")
                        }

                        // Notes
                        Button {
                            noteDraft = existingNote(for: verse)?.content ?? ""
                            showNoteSheet = true
                        } label: {
                            Image(systemName: "note.text")
                        }

                        // Bookmark toggle
                        Button {
                            if isBookmarked(verse) {
                                removeBookmark(for: verse)
                                toastSymbol = "bookmark.slash.fill"
                                toastTint = .red
                                toastText = "Removed Bookmark"
                            } else {
                                _ = addBookmark(for: verse)
                                toastSymbol = "bookmark.fill"
                                toastTint = .blue
                                toastText = "Bookmarked \(book.name) \(chapter.number):\(verse.number)"
                            }
                            withAnimation(.spring()) { showToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeOut) { showToast = false }
                            }
                        } label: {
                            Image(systemName: isBookmarked(verse) ? "bookmark.fill" : "bookmark")
                        }

                        // Favorite toggle
                        Button {
                            toggleFavorite(for: verse)
                        } label: {
                            Image(systemName: isFavorited(verse) ? "heart.fill" : "heart")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .sheet(isPresented: $showNoteSheet) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add Note")
                                .font(.headline)
                            TextEditor(text: $noteDraft)
                                .frame(minHeight: 160)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            Spacer()
                        }
                        .padding()
                        .navigationTitle("Note")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showNoteSheet = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    saveNote(for: verse, content: noteDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                                    showNoteSheet = false
                                }
                                .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }
            }
            .appToast(isPresented: $showToast, symbol: toastSymbol, text: toastText, tint: toastTint)
        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .navigationBarTitleDisplayMode(.large)
    }

    private func isFavorited(_ verse: Verse) -> Bool {
        favorites.contains { fav in
            fav.bookName == book.name && fav.chapterNumber == chapter.number && fav.verseNumber == verse.number
        }
    }

    private func isBookmarked(_ verse: Verse) -> Bool {
        bookmarks.contains { bm in
            bm.bookName == book.name && bm.chapterNumber == chapter.number && bm.verseNumber == verse.number
        }
    }

    private func existingNote(for verse: Verse) -> VerseNote? {
        notes.first { n in
            n.bookName == book.name && n.chapterNumber == chapter.number && n.verseNumber == verse.number
        }
    }

    private func saveNote(for verse: Verse, content: String) {
        if let existing = existingNote(for: verse) {
            existing.content = content
            existing.updatedAt = Date()
            try? modelContext.save()
        } else {
            let note = VerseNote(
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text,
                content: content,
                createdAt: Date(),
                updatedAt: Date()
            )
            modelContext.insert(note)
            try? modelContext.save()
        }
    }

    @discardableResult
    private func addBookmark(for verse: Verse) -> Bool {
        if isBookmarked(verse) { return false }
        let bookmark = Bookmark(
            bookName: book.name,
            chapterNumber: chapter.number,
            verseNumber: verse.number,
            verseText: verse.text
        )
        modelContext.insert(bookmark)
        try? modelContext.save()
        return true
    }

    private func removeBookmark(for verse: Verse) {
        if let existing = bookmarks.first(where: { $0.bookName == book.name && $0.chapterNumber == chapter.number && $0.verseNumber == verse.number }) {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    private func toggleFavorite(for verse: Verse) {
        if let existing = favorites.first(where: { $0.bookName == book.name && $0.chapterNumber == chapter.number && $0.verseNumber == verse.number }) {
            modelContext.delete(existing)
            try? modelContext.save()
            toastSymbol = "xmark.circle.fill"
            toastTint = .red
            toastText = "Removed Favorite"
        } else {
            let fav = Favorite(
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text
            )
            modelContext.insert(fav)
            try? modelContext.save()
            toastSymbol = "heart.fill"
            toastTint = .pink
            toastText = "Favorited \(book.name) \(chapter.number):\(verse.number)"
        }
        withAnimation(.spring()) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut) { showToast = false }
        }
    }
}

#Preview {
    NavigationStack {
        VersesView(book: BibleData.books.first!, chapter: BibleData.books.first!.chapters.first!)
            .environmentObject(NavigationCoordinator())
    }
}
