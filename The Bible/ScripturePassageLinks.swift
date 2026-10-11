import SwiftUI
import UIKit

/// A passage cited in study content: a verse, a verse range, a chapter, or a chapter range.
struct PassageReference: Identifiable, Hashable {
    let bookName: String
    let startChapter: Int
    /// `nil` when the reference names whole chapters.
    let startVerse: Int?
    let endChapter: Int
    let endVerse: Int?

    var id: String { displayTitle }

    var isSingleChapter: Bool { startChapter == endChapter }

    var displayTitle: String {
        let start = startVerse.map { "\(startChapter):\($0)" } ?? "\(startChapter)"
        switch (startVerse, endVerse) {
        case let (startVerse?, endVerse?) where isSingleChapter:
            return endVerse == startVerse
                ? "\(bookName) \(start)"
                : "\(bookName) \(start)–\(endVerse)"
        case (_, let endVerse?):
            return "\(bookName) \(start)–\(endChapter):\(endVerse)"
        case (_, nil):
            return isSingleChapter ? "\(bookName) \(start)" : "\(bookName) \(start)–\(endChapter)"
        }
    }

    // MARK: In-app link URL

    private static let scheme = "thebible"
    private static let host = "passage"

    /// Link target used inside rendered text; opened by `scripturePassagePreviews()`.
    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        var items = [
            URLQueryItem(name: "book", value: bookName),
            URLQueryItem(name: "fromChapter", value: "\(startChapter)"),
            URLQueryItem(name: "toChapter", value: "\(endChapter)")
        ]
        if let startVerse { items.append(URLQueryItem(name: "fromVerse", value: "\(startVerse)")) }
        if let endVerse { items.append(URLQueryItem(name: "toVerse", value: "\(endVerse)")) }
        components.queryItems = items
        return components.url ?? URL(string: "thebible://passage")!
    }

    init(bookName: String, startChapter: Int, startVerse: Int?, endChapter: Int, endVerse: Int?) {
        self.bookName = bookName
        self.startChapter = startChapter
        self.startVerse = startVerse
        self.endChapter = endChapter
        self.endVerse = endVerse
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host == Self.host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let book = value("book"),
              let fromChapter = value("fromChapter").flatMap(Int.init),
              let toChapter = value("toChapter").flatMap(Int.init) else { return nil }
        self.init(
            bookName: book,
            startChapter: fromChapter,
            startVerse: value("fromVerse").flatMap(Int.init),
            endChapter: toChapter,
            endVerse: value("toVerse").flatMap(Int.init)
        )
    }
}

/// Finds passage references in study text, such as "Matthew 5:3–12", "Genesis 12-50",
/// "Deuteronomy 19:15", or "Psalm 23", and validates them against the corpus.
@MainActor
enum PassageReferenceParser {
    /// Alternate spellings found in study content.
    private static let aliases = [
        "Psalm": "Psalms",
        "Song of Songs": "Song of Solomon",
        "Revelations": "Revelation"
    ]

    private static var cachedRegex: NSRegularExpression?
    private static var cachedBookCount = 0

    /// Built from the loaded corpus; rebuilt if the corpus finished loading after first use.
    private static var regex: NSRegularExpression? {
        let books = BibleData.books
        if let cachedRegex, cachedBookCount == books.count { return cachedRegex }
        guard !books.isEmpty else { return nil }

        // Longest names first so "1 John" wins over "John" and "Psalms" over "Psalm".
        let names = (books.map(\.name) + aliases.keys)
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let pattern = #"(?<![A-Za-z0-9])("# + names
            + #")\s+(\d{1,3})(?::(\d{1,3}))?(?:\s*[-–—]\s*(\d{1,3})(?::(\d{1,3}))?)?(?![0-9:])"#
        cachedRegex = try? NSRegularExpression(pattern: pattern)
        cachedBookCount = books.count
        return cachedRegex
    }

    /// Parses a string that is entirely a reference, such as a list entry.
    static func parse(_ text: String) -> PassageReference? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = matches(in: trimmed).first,
              match.range == trimmed.startIndex..<trimmed.endIndex else { return nil }
        return match.reference
    }

    /// Parses a reference-list entry, filling in what the study data leaves out using the
    /// book and chapter being shown. Handles entries such as "1:2-4" (no book), "20-23"
    /// (verses only), "Leviticus 1:1:1–3" (doubled chapter), and "3:11-13,40-45" (several
    /// passages), which becomes one reference per passage.
    static func parseList(_ text: String, book contextBook: String?, chapter contextChapter: Int?) -> [PassageReference] {
        if let reference = parse(text) { return [reference] }

        var entry = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // "Leviticus 1:1:1–3" → "Leviticus 1:1–3"
        entry = entry.replacingOccurrences(
            of: #"(\d+):\1:(\d)"#,
            with: "$1:$2",
            options: .regularExpression
        )

        // Split off a leading book name; the rest is chapter/verse locations.
        var bookName = contextBook
        var locations = entry
        if let leading = leadingBookName(in: entry) {
            bookName = leading.book
            locations = leading.remainder
        } else if let first = entry.first, !first.isNumber {
            return []
        }
        guard let bookName else { return [] }

        var chapter = contextChapter
        var references: [PassageReference] = []
        for part in locations.split(whereSeparator: { $0 == "," || $0 == ";" }) {
            let piece = part.trimmingCharacters(in: .whitespaces)
            guard let firstCharacter = piece.first, firstCharacter.isNumber else { continue }
            let candidate: String
            if piece.contains(":") {
                // "3:11-13" names its own chapter, which later pieces inherit.
                chapter = piece.split(separator: ":").first.flatMap { Int($0) } ?? chapter
                candidate = "\(bookName) \(piece)"
            } else if let chapter {
                // "40-45" continues in the current chapter.
                candidate = "\(bookName) \(chapter):\(piece)"
            } else {
                candidate = "\(bookName) \(piece)"
            }
            if let reference = parse(candidate) {
                references.append(reference)
            }
        }
        return references
    }

    /// A book name at the start of `text` (including spellings such as "Psalm") and the text after it.
    private static func leadingBookName(in text: String) -> (book: String, remainder: String)? {
        let names = (BibleData.books.map(\.name) + aliases.keys).sorted { $0.count > $1.count }
        for name in names where text.hasPrefix(name + " ") {
            let remainder = text.dropFirst(name.count).trimmingCharacters(in: .whitespaces)
            return (aliases[name] ?? name, remainder)
        }
        return nil
    }

    /// Every valid reference in `text` with its location.
    static func matches(in text: String) -> [(range: Range<String.Index>, reference: PassageReference)] {
        guard let regex else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text),
                  let reference = reference(from: match, in: text) else { return nil }
            return (range, reference)
        }
    }

    /// The text with every reference turned into a link to its preview.
    static func linkified(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for match in matches(in: text) {
            guard let lower = AttributedString.Index(match.range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(match.range.upperBound, within: attributed) else { continue }
            attributed[lower..<upper].link = match.reference.url
        }
        return attributed
    }

    private static func reference(from match: NSTextCheckingResult, in text: String) -> PassageReference? {
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
        func number(_ index: Int) -> Int? { group(index).flatMap(Int.init) }

        guard let rawBook = group(1),
              let chapter = number(2) else { return nil }
        let bookName = aliases[rawBook] ?? rawBook
        let verse = number(3)
        let rangeFirst = number(4)
        let rangeSecond = number(5)

        let endChapter: Int
        let endVerse: Int?
        switch (verse, rangeFirst, rangeSecond) {
        case let (_, to?, toVerse?):        // "John 3:16–4:2" or "Genesis 1–2:3"
            endChapter = to
            endVerse = toVerse
        case let (verse?, to?, nil):        // "Matthew 5:3–12"
            endChapter = chapter
            endVerse = max(verse, to)
        case let (verse?, nil, nil):        // "Deuteronomy 19:15"
            endChapter = chapter
            endVerse = verse
        case let (nil, to?, nil):           // "Genesis 12–50"
            endChapter = to
            endVerse = nil
        default:                            // "Psalm 23"
            endChapter = chapter
            endVerse = nil
        }

        let reference = PassageReference(
            bookName: bookName,
            startChapter: chapter,
            startVerse: verse,
            endChapter: endChapter,
            endVerse: endVerse
        )
        return isValid(reference) ? reference : nil
    }

    private static func isValid(_ reference: PassageReference) -> Bool {
        guard let book = BibleData.books.first(where: { $0.name == reference.bookName }),
              reference.startChapter >= 1,
              reference.endChapter >= reference.startChapter,
              reference.endChapter <= book.chapters.count else { return false }
        if let startVerse = reference.startVerse,
           startVerse > book.chapters[reference.startChapter - 1].verses.count { return false }
        if let endVerse = reference.endVerse,
           endVerse > book.chapters[reference.endChapter - 1].verses.count { return false }
        return true
    }
}

// MARK: - Views

/// Study text whose passage references are tappable previews.
struct LinkedScriptureText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(PassageReferenceParser.linkified(text))
    }
}

/// A wrapping row of tappable reference chips. `book` and `chapter` fill in entries that
/// omit them; entries that still cannot be read are shown as plain labels.
struct PassageReferenceChips: View {
    let references: [String]
    var book: String?
    var chapter: Int?

    private enum Chip: Identifiable {
        case passage(PassageReference)
        case text(String)

        var id: String {
            switch self {
            case .passage(let reference): "passage-\(reference.id)"
            case .text(let text): "text-\(text)"
            }
        }
    }

    private var chips: [Chip] {
        var seen = Set<String>()
        return references.flatMap { text -> [Chip] in
            let parsed = PassageReferenceParser.parseList(text, book: book, chapter: chapter)
            let entries = parsed.isEmpty ? [Chip.text(text)] : parsed.map(Chip.passage)
            return entries.filter { seen.insert($0.id).inserted }
        }
    }

    var body: some View {
        PassageFlowLayout(spacing: 8) {
            ForEach(chips) { chip in
                switch chip {
                case .passage(let reference):
                    Link(destination: reference.url) {
                        Label(reference.displayTitle, systemImage: "book")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                    .accessibilityHint("Shows a preview of the passage")
                case .text(let text):
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            }
        }
    }
}

extension View {
    /// Shows a scripture preview sheet when a passage link inside this view is tapped.
    func scripturePassagePreviews() -> some View {
        modifier(ScripturePassagePreviewModifier())
    }
}

private struct ScripturePassagePreviewModifier: ViewModifier {
    @State private var selectedPassage: PassageReference?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let reference = PassageReference(url: url) else { return .systemAction }
                selectedPassage = reference
                return .handled
            })
            .sheet(item: $selectedPassage) { reference in
                ScripturePassageSheet(reference: reference)
            }
    }
}

/// Preview of a cited passage with Copy, Share, and Open in Bible.
struct ScripturePassageSheet: View {
    @Environment(\.dismiss) private var dismiss

    let reference: PassageReference

    /// Long chapter ranges preview only their first chapter.
    private static let maximumPreviewChapters = 3

    private struct ChapterSection: Identifiable {
        let chapter: Int
        let verses: [Verse]
        var id: Int { chapter }
    }

    @State private var sections: [ChapterSection] = []
    @State private var isTruncated = false
    @State private var isLoading = true
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Loading scripture…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if sections.isEmpty {
                        ContentUnavailableView(
                            "Scripture Unavailable",
                            systemImage: "book.closed",
                            description: Text("This passage could not be loaded.")
                        )
                    } else {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                if sections.count > 1 || !reference.isSingleChapter {
                                    Text("\(reference.bookName) \(section.chapter)")
                                        .font(.headline)
                                }
                                ForEach(section.verses) { verse in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(verse.number, format: .number)
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                            .frame(minWidth: 24, alignment: .trailing)
                                        Text(verse.text)
                                            .font(.body)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                        .textSelection(.enabled)

                        if isTruncated {
                            Text("Showing \(reference.bookName) \(reference.startChapter). Open in Bible to keep reading.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: openInBible) {
                    Label("Open in Bible", systemImage: "book")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .disabled(sections.isEmpty)
            }
            .navigationTitle(reference.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: reference.id) { await load() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close scripture")
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        UIPasteboard.general.string = shareText
                        Haptics.selection()
                        didCopy = true
                    } label: {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    }
                    .accessibilityLabel(didCopy ? "Copied" : "Copy scripture")
                    .disabled(sections.isEmpty)

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share scripture")
                    .disabled(sections.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var shareText: String {
        let body = sections.map { section in
            section.verses.map { "\(section.chapter):\($0.number) \($0.text)" }.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
        return "\(reference.displayTitle)\n\n\(body)"
    }

    private func load() async {
        isLoading = true
        let books = await BibleRepository.shared.loadAllBooks()
        defer { isLoading = false }
        guard let book = books.first(where: { $0.name == reference.bookName }) else {
            sections = []
            return
        }

        let chapterCount = reference.endChapter - reference.startChapter + 1
        isTruncated = chapterCount > Self.maximumPreviewChapters
        let lastChapter = isTruncated ? reference.startChapter : reference.endChapter

        sections = (reference.startChapter...lastChapter).compactMap { number in
            guard book.chapters.indices.contains(number - 1) else { return nil }
            let verses = book.chapters[number - 1].verses
            let from = number == reference.startChapter ? (reference.startVerse ?? 1) : 1
            let to = (number == reference.endChapter ? reference.endVerse : nil) ?? Int.max
            let selected = verses.filter { $0.number >= from && $0.number <= to }
            return selected.isEmpty ? nil : ChapterSection(chapter: number, verses: selected)
        }
    }

    private func openInBible() {
        let destination = reference
        dismiss()
        // Navigate after the sheet starts dismissing so the reader can take over.
        DispatchQueue.main.async {
            AppRouter.shared.openBibleReference(
                book: destination.bookName,
                chapter: destination.startChapter,
                verse: destination.startVerse ?? 1
            )
        }
    }
}

/// Wraps its children onto as many rows as needed, left to right.
private struct PassageFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
