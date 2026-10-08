import SwiftUI

struct ChaptersView: View {
    let book: Book
    @EnvironmentObject private var coordinator: NavigationCoordinator

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if book.name == "Genesis" {
                    GenesisChapterHeader(chapterCount: book.chapters.count)
                } else if let theme = BibleSplitView.BookChapterTheme.themes[book.name] {
                    BibleSplitView.ThemedBookChaptersHeader(title: book.name, theme: theme)
                }

                NavigationLink {
                    BookOverviewView(bookName: book.name)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "book.closed.fill")
                            .font(.title3)
                            .foregroundStyle(.tint)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("About \(book.name)")
                                .font(.headline)
                            Text("Background, themes, and key passages")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppDesignMetrics.cardPadding)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .heroCardSurface()

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
            }
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .background(AppBackgroundView(tab: .bible))
        // Genesis already has its own styled title card in the content.
        .navigationTitle(book.name == "Genesis" ? "" : book.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GenesisChapterHeader: View {
    let chapterCount: Int

    var body: some View {
        HStack(spacing: 16) {
            GenesisCreationEmblem()

            VStack(alignment: .leading, spacing: 4) {
                Text("Genesis")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("The beginning")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(chapterCount) chapters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
        .accessibilityElement(children: .combine)
    }
}

private struct GenesisCreationEmblem: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "sun.max.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .offset(x: -8, y: -8)

            Image(systemName: "leaf.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))
                .rotationEffect(.degrees(-25))
                .offset(x: 12, y: 12)
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        ChaptersView(book: BibleData.books.first!)
    }
}
