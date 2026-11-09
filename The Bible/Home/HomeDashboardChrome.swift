import SwiftUI

// Pieces of the iPad Home dashboard that sit around the cards: the Edit Home hint, the
// Today's Reading edit controls, and the quick actions shown when every card is hidden.

/// Instructions shown above the columns while Edit Home is on.
struct HomeEditHint: View {
    var body: some View {
        Label {
            Text("Use the arrows to move cards up, down, left, or right. Tap – to hide a card, or \(Image(systemName: "arrow.left.and.right")) to widen Verse of the Day. Tap Done when you're finished.")
        } icon: {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

/// Edit Home controls for the Today's Reading panel: move it to another column or hide it.
struct HomeBibleReaderEditControls: View {
    @Binding var column: HomeColumn
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: 8) {
            HomeEditControlButton(
                systemImage: "arrow.left",
                label: "Move Today's Reading left",
                disabled: column.neighbor(by: -1) == nil
            ) {
                move(by: -1)
            }

            Button {
                withAnimation(.snappy) { isVisible = false }
                Haptics.selection()
            } label: {
                Label("Hide", systemImage: "eye.slash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Hide Today's Reading")

            HomeEditControlButton(
                systemImage: "arrow.right",
                label: "Move Today's Reading right",
                disabled: column.neighbor(by: 1) == nil
            ) {
                move(by: 1)
            }
        }
        .frame(height: HomeCardEditChrome.barHeight)
    }

    /// Moves the Today's Reading panel to the neighboring column; cards there stay below it.
    private func move(by offset: Int) {
        guard let destination = column.neighbor(by: offset) else { return }
        withAnimation(.snappy) { column = destination }
        Haptics.selection()
    }
}

/// The three large actions shown on iPad when every card and the reader are hidden.
struct HomeMinimalQuickActions: View {
    /// The bookmarked verse, or the chapter last read (approximate, so no verse).
    private var continueMessage: String {
        guard let target else { return String(localized: "Start at Genesis 1") }
        switch target.primary {
        case .bookmark(let point): return "\(point.bookName) \(point.chapterNumber):\(point.verseNumber)"
        case .reading(let point): return "\(point.bookName) \(point.chapterNumber)"
        }
    }

    private var bookmarkText: String? {
        if case .bookmark(let point) = target?.primary { return point.verseText }
        return nil
    }

    private var isBookmark: Bool {
        if case .bookmark = target?.primary { return true }
        return false
    }

    let target: ContinueReadingTarget?
    let onOpenBooks: () -> Void
    let onContinueReading: () -> Void
    let onSearch: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            actionCard(
                title: "Books",
                message: "Browse the Bible",
                icon: "book.fill",
                tint: .blue,
                action: onOpenBooks
            )

            actionCard(
                title: "Continue Reading",
                message: continueMessage,
                verseText: bookmarkText,
                icon: isBookmark ? "bookmark.fill" : "book.fill",
                tint: .indigo,
                action: onContinueReading
            )

            actionCard(
                title: "Search",
                message: "Find a passage, word, or topic",
                icon: "magnifyingglass",
                tint: .teal,
                action: onSearch
            )
        }
    }

    private func actionCard(
        title: String,
        message: String,
        verseText: String? = nil,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HeroCard(title: title, subtitle: nil, icon: icon, tint: tint) {
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let verseText, !verseText.isEmpty {
                    Text("“\(verseText)”")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                Label("Open", systemImage: "arrow.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 104, weight: .bold))
                    .foregroundStyle(tint.opacity(0.12))
                    .padding(12)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityHint(message)
    }
}
