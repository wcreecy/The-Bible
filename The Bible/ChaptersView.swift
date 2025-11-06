import SwiftUI

struct ChaptersView: View {
    let book: Book
    @EnvironmentObject private var coordinator: NavigationCoordinator

    var body: some View {
        List(book.chapters) { chapter in
            Button {
                coordinator.push(.chapter(book: book, chapter: chapter))
            } label: {
                HStack(spacing: 0) {
                    Text("Chapter \(chapter.number)")
                    Text(" of \(book.chapters.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        ChaptersView(book: BibleData.books.first!)
    }
}
