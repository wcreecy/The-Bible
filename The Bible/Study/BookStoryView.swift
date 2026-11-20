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
    case "Proverbs":
        "Proverbs: Wisdom for Daily Life"
    case "Ecclesiastes":
        "Ecclesiastes: Searching for Meaning"
    case "Song of Solomon":
        "Song of Solomon: A Celebration of Love"
    case "Isaiah":
        "Isaiah: Judgment, Hope, and the Coming King"
    case "Jeremiah":
        "Jeremiah: A Prophet Through Judah’s Fall"
    case "Lamentations":
        "Lamentations: Grief After Jerusalem’s Fall"
    case "Ezekiel":
        "Ezekiel: God’s Glory, Judgment, and Restoration"
    case "Daniel":
        "Daniel: Faithful in Exile"
    case "Hosea":
        "Hosea: Love That Calls Us Home"
    case "Joel":
        "Joel: Return, Restore, and Renew"
    case "Amos":
        "Amos: Let Justice Roll Down"
    case "Obadiah":
        "Obadiah: Pride Falls, Justice Comes"
    case "Jonah":
        "Jonah: Mercy for an Enemy"
    case "Micah":
        "Micah: Justice, Mercy, and Humility"
    case "Nahum":
        "Nahum: Justice for the Oppressed"
    case "Habakkuk":
        "Habakkuk: Trusting God in the Questions"
    case "Zephaniah":
        "Zephaniah: Judgment and Joyful Restoration"
    case "Haggai":
        "Haggai: Rebuild With God"
    case "Zechariah":
        "Zechariah: Return, Rebuild, and Hope"
    case "Malachi":
        "Malachi: Return to Faithful Love"
    case "Matthew":
        "Matthew: Jesus the Promised King"
    case "Mark":
        "Mark: Jesus the Servant King"
    case "Luke":
        "Luke: Jesus, Friend of the Lost"
    case "John":
        "John: Jesus, the Word Made Flesh"
    case "Acts":
        "Acts: The Gospel Goes Out"
    case "Romans":
        "Romans: The Good News of God’s Grace"
    case "1 Corinthians":
        "1 Corinthians: Love Builds the Church"
    case "2 Corinthians":
        "2 Corinthians: Strength in Weakness"
    case "Galatians":
        "Galatians: Freedom Through Faith"
    case "Ephesians":
        "Ephesians: One New Family in Christ"
    case "Philippians":
        "Philippians: Joy in Christ"
    case "Colossians":
        "Colossians: Christ Is Enough"
    case "1 Thessalonians":
        "1 Thessalonians: Hope While We Wait"
    case "2 Thessalonians":
        "2 Thessalonians: Steady Hope in Troubled Times"
    case "1 Timothy":
        "1 Timothy: Leading With Truth and Care"
    case "2 Timothy":
        "2 Timothy: Finish the Race Faithfully"
    case "Titus":
        "Titus: Grace That Builds a Healthy Church"
    case "Philemon":
        "Philemon: A Call to Reconciliation"
    case "Hebrews":
        "Hebrews: Jesus Is Greater"
    case "James":
        "James: Faith That Works"
    case "1 Peter":
        "1 Peter: Living Hope in Hard Times"
    case "2 Peter":
        "2 Peter: Grow in Grace and Truth"
    case "1 John":
        "1 John: Walk in the Light and Love"
    case "2 John":
        "2 John: Truth and Love Together"
    case "3 John":
        "3 John: Faithful Hospitality and Humble Leadership"
    case "Jude":
        "Jude: Contend With Truth and Mercy"
    case "Revelation":
        "Revelation: Jesus Wins and Makes All Things New"
    default:
        "\(bookName): A Plain-English Retelling"
    }
}

/// A full-page, story-style retelling of a book, with each part labeled by the passage it covers.
struct BookStoryView: View {
    let bookName: String
    let story: [BibleBookStorySection]

    @State private var canonicalBookNames: [String] = []
    @State private var currentSectionID: Int?
    @State private var didRestorePosition = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    Text(bookRetellingTitle(for: bookName))
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
                        .id(section.id)
                        .onAppear {
                            currentSectionID = section.id
                            guard didRestorePosition else { return }
                            BookStoryProgress.save(section.id, for: bookName)
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
            .onAppear {
                let savedSectionID = BookStoryProgress.savedSectionID(for: bookName)
                currentSectionID = savedSectionID
                Task { @MainActor in
                    await Task.yield()
                    if let savedSectionID {
                        proxy.scrollTo(savedSectionID, anchor: .top)
                    }
                    didRestorePosition = true
                }
            }
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

/// Stores one resumable section per retelling without creating a Scripture bookmark.
enum BookStoryProgress {
    private static let defaults = UserDefaults.standard

    static func savedSectionID(for bookName: String, defaults: UserDefaults = defaults) -> Int? {
        guard
            let data = defaults.data(forKey: AppStorageKey.bookStoryProgress),
            let progress = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return nil }
        return progress[bookName]
    }

    static func save(_ sectionID: Int, for bookName: String, defaults: UserDefaults = defaults) {
        var progress = defaults.data(forKey: AppStorageKey.bookStoryProgress)
            .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
        progress[bookName] = sectionID
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: AppStorageKey.bookStoryProgress)
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
                .accessibilityHint("Opens the retelling of \(previousBookName)")
            }

            Spacer(minLength: 0)

            if let nextBookName {
                NavigationLink {
                    BookStoryDestinationView(bookName: nextBookName)
                } label: {
                    Label("Next: \(nextBookName)", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityHint("Opens the retelling of \(nextBookName)")
            }
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.glass)
        .padding(.top, 12)
    }
}

/// Loads an adjacent book's story before displaying it.
struct BookStoryDestinationView: View {
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
                    description: Text("The retelling of \(bookName) could not be found.")
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
