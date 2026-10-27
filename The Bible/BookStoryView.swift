import SwiftUI

/// Uses genre-appropriate titles for books that are reflective retellings rather than continuous narratives.
func bookRetellingTitle(for bookName: String) -> String {
    switch bookName {
    case "1 Chronicles":
        "1 Chronicles: Identity and Worship"
    case "2 Chronicles":
        "2 Chronicles: Temple, Kings, and Hope"
    case "Ezra":
        "Ezra: Return and Rebuild"
    case "Nehemiah":
        "Nehemiah: Rebuild and Renew"
    case "Esther":
        "Esther: Courage in Exile"
    case "Job":
        "Job: Wrestling with Suffering"
    case "Psalms":
        "Psalms: Prayers for Every Season"
    default:
        "The Story of \(bookName)"
    }
}

/// A full-page, story-style retelling of a book, with each part labeled by the passage it covers.
struct BookStoryView: View {
    let bookName: String
    let story: [BibleBookStorySection]

    @State private var canonicalBookNames: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(bookRetellingTitle(for: bookName))
                    .font(.largeTitle.bold())
                    .padding(.bottom, 4)

                ForEach(story) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        // Continuation paragraphs have no label of their own.
                        if !section.passage.isEmpty {
                            StorySectionHeader(passage: section.passage)
                        }

                        if let summary = section.summary {
                            StorySectionSummary(text: summary)
                        }

                        Text(section.narrative)
                            .font(.body)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text("Retold from the King James Version. Tap a passage to read it in full.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                BookStoryNavigation(
                    bookName: bookName,
                    canonicalBookNames: canonicalBookNames
                )
            }
            // Keeps lines a comfortable reading length on iPad.
            .frame(maxWidth: 680, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle(bookName)
        .navigationBarTitleDisplayMode(.inline)
        .scripturePassagePreviews()
        .task {
            guard canonicalBookNames.isEmpty else { return }
            canonicalBookNames = await BibleRepository.shared.loadAllBooks().map(\.name)
        }
    }
}

/// Buttons that continue through book stories in the Bible's canonical order.
private struct BookStoryNavigation: View {
    let bookName: String
    let canonicalBookNames: [String]

    private var bookIndex: Int? {
        canonicalBookNames.firstIndex(of: bookName)
    }

    private var previousBookName: String? {
        guard let bookIndex, bookIndex > canonicalBookNames.startIndex else { return nil }
        return canonicalBookNames[canonicalBookNames.index(before: bookIndex)]
    }

    private var nextBookName: String? {
        guard let bookIndex, bookIndex < canonicalBookNames.index(before: canonicalBookNames.endIndex) else {
            return nil
        }
        return canonicalBookNames[canonicalBookNames.index(after: bookIndex)]
    }

    var body: some View {
        HStack(spacing: 12) {
            if let previousBookName {
                NavigationLink {
                    BookStoryDestinationView(bookName: previousBookName)
                } label: {
                    Label("Previous: \(previousBookName)", systemImage: "chevron.left")
                }
                .accessibilityHint("Opens the story of \(previousBookName)")
            }

            Spacer(minLength: 0)

            if let nextBookName {
                NavigationLink {
                    BookStoryDestinationView(bookName: nextBookName)
                } label: {
                    Label("Next: \(nextBookName)", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityHint("Opens the story of \(nextBookName)")
            }
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.bordered)
        .padding(.top, 12)
    }
}

/// Loads an adjacent book's story before displaying it.
private struct BookStoryDestinationView: View {
    let bookName: String

    @State private var story: [BibleBookStorySection]?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading story…")
            } else if let story {
                BookStoryView(bookName: bookName, story: story)
            } else {
                ContentUnavailableView(
                    "Story Unavailable",
                    systemImage: "book.closed",
                    description: Text("The story of \(bookName) could not be found.")
                )
            }
        }
        .task(id: bookName) {
            isLoading = true
            story = await BibleBookOverviewRepository.shared.overview(forBookNamed: bookName)?.story
            isLoading = false
        }
    }
}

/// Displays a bold section title and a separate tappable reference when both are stored together.
private struct StorySectionHeader: View {
    let passage: String

    var body: some View {
        if let heading = heading {
            Text(heading.title)
                .font(.headline.bold())

            PassageLabel(passage: heading.reference)
        } else {
            PassageLabel(passage: passage)
        }
    }

    private var heading: (title: String, reference: String)? {
        guard passage.hasSuffix(")"),
              let separator = passage.range(of: " (", options: .backwards) else {
            return nil
        }

        let title = String(passage[..<separator.lowerBound])
        let reference = String(passage[separator.upperBound...].dropLast())
        guard !title.isEmpty, !reference.isEmpty else { return nil }
        return (title, reference)
    }
}

/// A section's one-line overview, set apart from the retelling with a tinted rule and italics.
private struct StorySectionSummary: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.italic())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(.tint)
                    .frame(width: 3)
            }
            .padding(.vertical, 4)
            .accessibilityLabel("Summary: \(text)")
    }
}

/// The passage a story section retells, shown as a link to its preview when it can be parsed.
private struct PassageLabel: View {
    let passage: String

    var body: some View {
        if let reference = PassageReferenceParser.parse(passage) {
            Link(destination: reference.url) {
                Label(reference.displayTitle, systemImage: "book")
            }
            .font(.subheadline.weight(.semibold))
            .accessibilityHint("Shows a preview of the passage")
        } else {
            Text(passage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    NavigationStack {
        BookStoryView(
            bookName: "Ruth",
            story: [
                BibleBookStorySection(id: 1, passage: "Naomi Loses Her Family in Moab (Ruth 1:1–22)", text: "A famine leads an Israelite family to Moab.\n\nIn the days when the judges ruled, there was a famine in the land."),
                BibleBookStorySection(id: 2, passage: "", text: "When Naomi heard that the LORD had visited his people by giving them bread, she set out for home.")
            ]
        )
    }
}
