import SwiftUI

/// A book's chapter themes and sections, loaded for the detailed chapter layout.
struct ChapterOutlineDetails: Equatable {
    var themeNames: [Int: [String]] = [:]
    var sections: [StudyChapterSection] = []

    static func load(for book: Book) async -> ChapterOutlineDetails {
        let bookName = book.name
        let chapterCount = book.chapters.count
        async let themes = ChapterInsightsRepository.shared.themeNames(forBookNamed: bookName)
        async let movements = BibleBookOverviewRepository.shared.movements(forBookNamed: bookName)

        return ChapterOutlineDetails(
            themeNames: await themes,
            sections: StudyChapterOutline.sections(
                bookName: bookName,
                movements: await movements.map { ($0.title, $0.keyPassages) },
                chapterCount: chapterCount
            )
        )
    }
}

/// A book's chapters as themed rows, under section headers when the book has an outline.
struct ChapterOutlineList<Row: View>: View {
    let chapterNumbers: [Int]
    let sections: [StudyChapterSection]
    @ViewBuilder let row: (Int) -> Row

    /// One column of rows on iPhone, more side by side on wider screens.
    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 10)]

    var body: some View {
        if sections.isEmpty {
            rows(chapterNumbers)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        ChapterSectionHeader(section: section)
                        rows(Array(section.chapters))
                    }
                }
            }
        }
    }

    private func rows(_ numbers: [Int]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(numbers, id: \.self) { number in
                row(number)
            }
        }
    }
}

private struct ChapterSectionHeader: View {
    let section: StudyChapterSection

    private var rangeLabel: String {
        let chapters = section.chapters
        return chapters.count == 1
            ? "Chapter \(chapters.lowerBound)"
            : "Chapters \(chapters.lowerBound)–\(chapters.upperBound)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.title)
                .font(.headline)
            Text(rangeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A chapter with its first key themes, so a book can be scanned by what each chapter is about.
struct ChapterThemeRow: View {
    let number: Int
    let themes: [String]

    private var themeSummary: String {
        themes.prefix(2).joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(number, format: .number)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .frame(minWidth: 40, minHeight: 40)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            Text(themeSummary.isEmpty ? "Chapter \(number)" : themeSummary)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(themeSummary.isEmpty ? "Chapter \(number) insights" : "Chapter \(number): \(themes.prefix(2).joined(separator: ", "))")
        .accessibilityHint("Opens chapter insights")
    }
}

/// The toolbar menu that switches the Study chapter list between the number grid and themed rows.
struct ChapterLayoutMenu: View {
    @Binding var layout: ChapterListLayout

    var body: some View {
        Menu {
            Picker("Chapter Layout", selection: $layout) {
                ForEach(ChapterListLayout.allCases) { layout in
                    Label(layout.title, systemImage: layout.systemImage).tag(layout)
                }
            }
        } label: {
            Label("Chapter layout", systemImage: layout.systemImage)
        }
    }
}
