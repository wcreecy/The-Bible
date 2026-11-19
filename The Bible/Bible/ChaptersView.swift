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
    /// The chapter whose insights or Scripture connections show in a sheet, after a Pencil
    /// squeeze on its number.
    @State private var insightsChapter: ChapterSheetTarget?
    @State private var connectionsChapter: ChapterSheetTarget?
    // One squeeze / double-tap handler for the whole grid, like the reader's, rather than one
    // per chapter: it opens the popover for the chapter the Pencil is over (or just left).
    @Environment(\.preferredPencilDoubleTapAction) private var pencilDoubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var pencilSqueezeAction
    @State private var hoveredChapter: Int?
    @State private var lastHoveredChapter: (number: Int, endedAt: Date?)?
    @State private var pencilChapter: ChapterSheetTarget?
    @State private var pencilAnchor: PopoverAttachmentAnchor = .point(.center)

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
                        GenesisChapterHeader()
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
                                isCompleted: completedChapters.contains("\(book.name):\(chapter.number)"),
                                onHoverChange: { isHovering in
                                    if isHovering {
                                        hoveredChapter = chapter.number
                                        lastHoveredChapter = (chapter.number, nil)
                                    } else if hoveredChapter == chapter.number {
                                        hoveredChapter = nil
                                        lastHoveredChapter = (chapter.number, Date())
                                    }
                                }
                            ) {
                                onSelectChapter(chapter)
                            }
                        }
                    }
                }
                .padding(AppDesignMetrics.cardPadding)
                .heroCardSurface()
                .onPencilDoubleTap { value in
                    guard pencilDoubleTapAction != .ignore else { return }
                    presentPencilPopover(at: value.hoverPose)
                }
                .onPencilSqueeze { phase in
                    guard pencilSqueezeAction != .ignore, case let .ended(value) = phase else { return }
                    presentPencilPopover(at: value.hoverPose)
                }
                .popover(item: $pencilChapter, attachmentAnchor: pencilAnchor) { target in
                    chapterPencilActions(for: target.number)
                        .presentationCompactAdaptation(.popover)
                }
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
        .sheet(item: $insightsChapter) { target in
            NavigationStack {
                ChapterInsightsView(bookName: book.name, chapterNumber: target.number)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { insightsChapter = nil }
                        }
                    }
            }
        }
        .sheet(item: $connectionsChapter) { target in
            ChapterConnectionsSheet(bookName: book.name, chapterNumber: target.number) {
                connectionsChapter = nil
            }
        }
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        // Genesis already has its own styled title card in the content.
        .navigationTitle(book.name == "Genesis" ? "" : book.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshCompletedChapters)
        .onChange(of: AppDataChanges.shared.bibleStats) {
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

    /// Opens the actions for the chapter under the Pencil: the one it's over, or was over a moment ago.
    private func presentPencilPopover(at pose: PencilHoverPose?) {
        let number: Int?
        if let hoveredChapter {
            number = hoveredChapter
        } else if let last = lastHoveredChapter,
                  last.endedAt.map({ Date().timeIntervalSince($0) < 1.5 }) ?? true {
            number = last.number
        } else {
            number = nil
        }
        guard let number else { return }
        // The pose is in the grid card's space, which is where the popover is attached.
        pencilAnchor = .point(pose?.anchor ?? .center)
        pencilChapter = ChapterSheetTarget(number: number)
    }

    private func chapterPencilActions(for number: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(book.name) \(number)")
                .font(.headline)
            chapterAction("Open", systemImage: "book") {
                if let chapter = book.chapters.first(where: { $0.number == number }) {
                    onSelectChapter(chapter)
                }
            }
            chapterAction("Chapter Insights", systemImage: "lightbulb") {
                insightsChapter = ChapterSheetTarget(number: number)
            }
            chapterAction("Cross-References", systemImage: "arrow.triangle.branch") {
                connectionsChapter = ChapterSheetTarget(number: number)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func chapterAction(_ title: LocalizedStringKey, systemImage: String, perform: @escaping () -> Void) -> some View {
        Button {
            pencilChapter = nil
            perform()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func refreshCompletedChapters() {
        completedChapters = BibleStatsStore.shared.loadVisitedChapters()
    }
}

/// A chapter cell in the chapter grid; the number turns green once the chapter is read.
private struct ChapterNumberButton: View {
    let number: Int
    let isCompleted: Bool
    let onHoverChange: (Bool) -> Void
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
                        .foregroundStyle(isCompleted ? Color.green : Color.primary)
                        .padding(.horizontal, 2)
                }
                .contentShape(Rectangle())
                .hoverEffect(.highlight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chapter \(number)")
        .accessibilityValue(isCompleted ? "Read" : "")
        .accessibilityHint("Opens the chapter")
        .onHover(perform: onHoverChange)
    }
}

/// Every Scripture connection in a chapter, loaded when it opens.
private struct ChapterConnectionsSheet: View {
    let bookName: String
    let chapterNumber: Int
    let onDone: () -> Void
    @State private var relatedVerses: [ChapterRelatedVerse]?

    var body: some View {
        NavigationStack {
            Group {
                if let relatedVerses {
                    ChapterCrossReferencesView(
                        bookName: bookName,
                        chapterNumber: chapterNumber,
                        relatedVerses: relatedVerses
                    )
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .task {
            relatedVerses = await ChapterInsightsRepository.shared
                .insights(forBookNamed: bookName, chapterNumber: chapterNumber)?
                .relatedVerses ?? []
        }
    }
}

/// A chapter chosen for a sheet.
private struct ChapterSheetTarget: Identifiable {
    let number: Int
    var id: Int { number }
}

/// Genesis's header. The chapter count isn't repeated here; it sits above the grid, as for every book.
private struct GenesisChapterHeader: View {
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
            }

            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
        .accessibilityElement(children: .combine)
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
