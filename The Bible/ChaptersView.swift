import SwiftUI

struct ChaptersView: View {
    let book: Book

    var body: some View {
        List(book.chapters) { chapter in
            NavigationLink(value: chapter) {
                HStack(spacing: 0) {
                    Text("Chapter \(chapter.number)")
                    Text(" of \(book.chapters.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(book.name)
        .navigationDestination(for: Chapter.self) { chapter in
            VersesView(book: book, chapter: chapter)
        }
    }
}

#Preview {
    NavigationStack {
        ChaptersView(book: BibleData.books.first!)
    }
}
