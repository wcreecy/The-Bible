import SwiftUI

struct ChaptersView: View {
    let book: Book
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var completedChapters: Set<String> = []

    // Cells grow with Dynamic Type so numbers stay readable at large sizes.
    @ScaledMetric(relativeTo: .body) private var cellMinimumWidth: CGFloat = 56

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: cellMinimumWidth), spacing: 10)]
    }

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

                VStack(alignment: .leading, spacing: 12) {
                    Text("\(book.chapters.count) chapters")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(book.chapters) { chapter in
                            ChapterNumberButton(
                                number: chapter.number,
                                isCompleted: completedChapters.contains("\(book.name):\(chapter.number)")
                            ) {
                                coordinator.push(.reader(book: book, chapter: chapter, startVerse: 1))
                            }
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
        .onAppear(perform: refreshCompletedChapters)
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            refreshCompletedChapters()
        }
    }

    private func refreshCompletedChapters() {
        completedChapters = BibleStatsStore.shared.loadVisitedChapters()
    }
}

/// A chapter cell in the chapter grid; completed chapters are tinted green.
private struct ChapterNumberButton: View {
    let number: Int
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .foregroundStyle(isCompleted ? Color.green : Color.primary)
                .background(
                    (isCompleted ? Color.green : Color.accentColor).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder((isCompleted ? Color.green : Color.accentColor).opacity(0.25), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chapter \(number)")
        .accessibilityValue(isCompleted ? "Read" : "")
        .accessibilityHint("Opens the chapter")
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
