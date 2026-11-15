import SwiftUI

/// Every chapter's "In Brief" summary for a book, in order, so the whole book can be
/// skimmed chapter by chapter.
struct BookChapterBriefsView: View {
    let bookName: String
    /// The chapter the reader came from, marked and scrolled into view.
    var currentChapter: Int? = nil
    /// When set, choosing a chapter hands it back and closes this page instead of pushing
    /// another insights page, so the chapter page that opened it can change in place.
    var onSelectChapter: ((Int) -> Void)? = nil

    @State private var briefs: [Int: String] = [:]
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private var chapterNumbers: [Int] {
        briefs.keys.sorted()
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading chapters…")
            } else if briefs.isEmpty {
                ContentUnavailableView(
                    "Chapter Summaries Unavailable",
                    systemImage: "text.quote",
                    description: Text("Chapter summaries for \(bookName) have not been added yet.")
                )
            } else {
                briefList
            }
        }
        .navigationTitle("\(bookName) Chapter by Chapter")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppBackgroundView(tab: .bible))
        .studySheetDoneButton()
        .task(id: bookName) {
            briefs = await ChapterInsightsRepository.shared.briefSummaries(forBookNamed: bookName)
            isLoading = false
        }
    }

    private var briefList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(chapterNumbers, id: \.self) { number in
                        row(for: number)
                            .id(number)
                    }
                }
                .padding()
            }
            .onAppear {
                if let currentChapter {
                    proxy.scrollTo(currentChapter, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for number: Int) -> some View {
        let isCurrent = number == currentChapter
        let content = ChapterBriefRow(
            chapterNumber: number,
            brief: briefs[number] ?? "",
            isCurrent: isCurrent
        )
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardSurface()

        if let onSelectChapter {
            Button {
                onSelectChapter(number)
                dismiss()
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens chapter \(number) insights")
        } else {
            NavigationLink {
                ChapterInsightsView(bookName: bookName, chapterNumber: number)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens chapter \(number) insights")
        }
    }
}

/// A chapter number and its one-sentence summary, shown in lists of a book's chapters.
struct ChapterBriefRow: View {
    let chapterNumber: Int
    let brief: String
    var isCurrent = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Chapter \(chapterNumber)")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    if isCurrent {
                        Text("Current")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
                Text(brief)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        BookChapterBriefsView(bookName: "Ruth", currentChapter: 2)
    }
}
