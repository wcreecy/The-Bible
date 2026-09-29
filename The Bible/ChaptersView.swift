import SwiftUI

struct ChaptersView: View {
    let book: Book
    @EnvironmentObject private var coordinator: NavigationCoordinator

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(book.chapters) { chapter in
                    Button {
                        coordinator.push(.chapter(book: book, chapter: chapter))
                    } label: {
                        HStack(spacing: 0) {
                            Text("Chapter \(chapter.number)")
                            Text(" of \(book.chapters.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: AppDesignMetrics.selectionRowMinHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    if chapter.number != book.chapters.last?.number {
                        Divider()
                    }
                }
            }
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChaptersView(book: BibleData.books.first!)
    }
}
