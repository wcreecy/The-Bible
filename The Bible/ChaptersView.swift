import SwiftUI

/// Chapter grid for a book, shared by iPhone navigation and the iPad split view.
struct ChaptersView: View {
    let book: Book
    /// Opens the chosen chapter; the host decides how (iPhone stack or iPad detail).
    let onSelectChapter: (Chapter) -> Void
    /// Lets an iPad host keep an overview open while the selected book changes.
    let onSelectOverview: (() -> Void)?
    @State private var completedChapters: Set<String> = []
    @State private var isShowingOverview = false
    @State private var headerHeight: CGFloat = 0
    @State private var isHeaderScrolledAway = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        book: Book,
        onSelectChapter: @escaping (Chapter) -> Void,
        onSelectOverview: (() -> Void)? = nil
    ) {
        self.book = book
        self.onSelectChapter = onSelectChapter
        self.onSelectOverview = onSelectOverview
    }

    // Cells grow with Dynamic Type so numbers stay readable at large sizes.
    @ScaledMetric(relativeTo: .body) private var cellMinimumWidth: CGFloat = 56

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: cellMinimumWidth), spacing: 10)]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    if book.name == "Genesis" {
                        GenesisChapterHeader(chapterCount: book.chapters.count)
                    } else if let theme = BookChapterTheme.themes[book.name] {
                        ThemedBookChaptersHeader(title: book.name, theme: theme)
                    }

                    overviewLink
                }
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { headerHeight = $0 }

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
                                onSelectChapter(chapter)
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
        // Matches StudyBookView: once most of the book header and About card scroll
        // away, a compact bar floats over the content so the overview stays one tap away.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let scrolled = geometry.contentOffset.y + geometry.contentInsets.top
            return headerHeight > 0 && scrolled > headerHeight * 0.75
        } action: { _, isScrolledAway in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.25)) {
                isHeaderScrolledAway = isScrolledAway
            }
        }
        .overlay(alignment: .top) {
            if isHeaderScrolledAway {
                CompactStudyBookHeader(bookName: book.name, onOpenOverview: openOverview)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationDestination(isPresented: $isShowingOverview) {
            BookOverviewView(bookName: book.name)
        }
        .background(AppBackgroundView(tab: .bible))
        // Genesis already has its own styled title card in the content.
        .navigationTitle(book.name == "Genesis" ? "" : book.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshCompletedChapters)
        .onNotification(.bibleStatsExternallyUpdated) {
            refreshCompletedChapters()
        }
    }

    private var overviewLink: some View {
        Button(action: openOverview) {
            overviewLabel
        }
        .buttonStyle(.plain)
    }

    /// Uses the host's overview handler on iPad; otherwise pushes the overview.
    private func openOverview() {
        if let onSelectOverview {
            onSelectOverview()
        } else {
            isShowingOverview = true
        }
    }

    private var overviewLabel: some View {
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
        .foregroundStyle(.primary)
        .heroCardSurface()
    }

    private func refreshCompletedChapters() {
        completedChapters = BibleStatsStore.shared.loadVisitedChapters()
    }
}

/// A chapter cell in the chapter grid; the number turns green once the chapter is read.
private struct ChapterNumberButton: View {
    let number: Int
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // The square cell sets the size and the number is laid over it, so the
            // number gets the full cell width and three-digit chapters are never truncated.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text("\(number)")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .foregroundStyle(isCompleted ? Color.green : Color.primary)
                        .padding(.horizontal, 2)
                }
                .contentShape(Rectangle())
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
    // Psalms-sized sample book so the preview shows three-digit chapter numbers.
    NavigationStack {
        ChaptersView(
            book: Book(
                name: "Psalms",
                chapters: (1...150).map { Chapter(number: $0, verses: [Verse(number: 1, text: "")]) }
            ),
            onSelectChapter: { _ in }
        )
    }
}
