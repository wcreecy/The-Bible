import SwiftUI

/// Shows what a passage says when the Apple Pencil (or a pointer) rests over its link, with no
/// tap needed. Hovering only previews; opening the passage is still a tap.
private struct PassageHoverPreviewModifier: ViewModifier {
    /// Worked out only when the preview opens, so a long list doesn't parse every reference.
    let references: () -> [PassageReference]

    @State private var isPresented = false
    @State private var pendingShow: Task<Void, Never>?

    /// Resting briefly first keeps a Pencil crossing a list from flashing previews.
    private static let hoverDelay: Duration = .milliseconds(350)

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                pendingShow?.cancel()
                guard isHovering else {
                    isPresented = false
                    return
                }
                pendingShow = Task {
                    try? await Task.sleep(for: Self.hoverDelay)
                    guard !Task.isCancelled else { return }
                    isPresented = true
                }
            }
            .popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                PassageHoverPreviewCard(references: references())
                    .presentationCompactAdaptation(.popover)
            }
    }
}

extension View {
    /// Previews passages in a popover while the Apple Pencil hovers over this view.
    /// Pass `isEnabled: false` when there is nothing to preview.
    @ViewBuilder
    func passageHoverPreview(
        isEnabled: Bool = true,
        _ references: @escaping () -> [PassageReference]
    ) -> some View {
        if isEnabled {
            modifier(PassageHoverPreviewModifier(references: references))
        } else {
            self
        }
    }
}

/// A short look at up to three passages: each one's title and its first few verses.
private struct PassageHoverPreviewCard: View {
    let references: [PassageReference]

    private struct Preview: Identifiable {
        let id: String
        let title: String
        let lines: [String]
        let isTruncated: Bool
    }

    @State private var previews: [Preview] = []
    @State private var isLoading = true

    private static let maximumPassages = 3
    private static let maximumVerses = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if previews.isEmpty {
                Text("This passage could not be loaded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(previews) { preview in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.title)
                            .font(.subheadline.weight(.semibold))
                        ForEach(preview.lines, id: \.self) { line in
                            Text(line)
                                .font(.callout)
                        }
                        if preview.isTruncated {
                            Text("…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if preview.id != previews.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(width: 320, alignment: .leading)
        .task { await load() }
    }

    private func load() async {
        let books = await BibleRepository.shared.loadAllBooks()
        previews = references.prefix(Self.maximumPassages).compactMap { reference in
            guard let book = books.first(where: { $0.name == reference.bookName }),
                  book.chapters.indices.contains(reference.startChapter - 1) else { return nil }

            // A preview covers the first chapter of the reference.
            let chapter = book.chapters[reference.startChapter - 1]
            let from = reference.startVerse ?? 1
            let to = (reference.isSingleChapter ? reference.endVerse : nil) ?? Int.max
            let verses = chapter.verses.filter { $0.number >= from && $0.number <= to && !$0.isOmitted }
            guard !verses.isEmpty else { return nil }

            let shown = verses.prefix(Self.maximumVerses)
            return Preview(
                id: reference.id,
                title: reference.displayTitle,
                lines: shown.map { "\($0.number) \($0.text)" },
                isTruncated: verses.count > shown.count
            )
        }
        isLoading = false
    }
}
