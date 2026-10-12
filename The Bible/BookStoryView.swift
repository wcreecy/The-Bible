import SwiftUI

/// A full-page, story-style retelling of a book, with each part labeled by the passage it covers.
struct BookStoryView: View {
    let bookName: String
    let story: [BibleBookStorySection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("The Story of \(bookName)")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 4)

                ForEach(story) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        // Continuation paragraphs have no label of their own.
                        if !section.passage.isEmpty {
                            StorySectionHeader(passage: section.passage)
                        }

                        Text(section.text)
                            .font(.body)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text("Retold from the King James Version. Tap a passage to read it in full.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            // Keeps lines a comfortable reading length on iPad.
            .frame(maxWidth: 680, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle(bookName)
        .navigationBarTitleDisplayMode(.inline)
        .scripturePassagePreviews()
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
                BibleBookStorySection(id: 1, passage: "Ruth 1", text: "In the days when the judges ruled, there was a famine in the land."),
                BibleBookStorySection(id: 2, passage: "", text: "When Naomi heard that the LORD had visited his people by giving them bread, she set out for home.")
            ]
        )
    }
}
