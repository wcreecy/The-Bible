import SwiftUI
import UIKit

struct VersesChecklistView: View {
    let bookName: String
    let chapterNumber: Int

    @State private var seen: Set<Int> = []
    @State private var verses: [Verse] = []
    @State private var totalVerses: Int = 0

    private var titleText: String { "\(bookName) \(chapterNumber)" }

    var body: some View {
        Group {
            if verses.isEmpty {
                ContentUnavailableView("No verses found", systemImage: "text.book.closed")
            } else {
                List {
                    Section {
                        ForEach(verses, id: \.number) { v in
                            HStack(spacing: 10) {
                                // Read-only indicator (no user toggling)
                                Image(systemName: seen.contains(v.number) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(seen.contains(v.number) ? .green : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Verse \(v.number)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(seen.contains(v.number) ? .secondary : .primary)
                                        .strikethrough(seen.contains(v.number), color: .secondary)
                                    Text(snippet(v.text))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            // Intentionally no tap: verses are only marked as read from the Bible tab’s reader when on-screen.
                        }
                    } header: {
                        Text(titleText)
                    } footer: {
                        Text("\(seen.count)/\(totalVerses) verses read")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChapter()
            refreshSeen()
        }
        // Refresh when returning from Bible tab via deep link/open event
        .onReceive(NotificationCenter.default.publisher(for: .openBibleReference)) { _ in
            refreshSeen()
        }
        // Also refresh when app returns to foreground (user may have read while this view was not visible)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshSeen()
        }
    }

    private func loadChapter() {
        guard let book = BibleData.books.first(where: { $0.name == bookName }),
              let chapter = book.chapters.first(where: { $0.number == chapterNumber }) else {
            verses = []
            totalVerses = 0
            return
        }
        verses = chapter.verses
        totalVerses = verses.count
    }

    private func refreshSeen() {
        seen = BibleStatsStore.shared.loadSeenVerses(bookName: bookName, chapter: chapterNumber)

        // If all verses are read, ensure the chapter is marked visited so upstream
        // “Chapters” and “Book Reading Progress” reflect completion.
        if totalVerses > 0, seen.count >= totalVerses {
            BibleStatsStore.shared.markVisited(bookName: bookName, chapterNumber: chapterNumber)
        }
    }

    private func snippet(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 100 { return "“\(trimmed)”" }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: 100)
        return "“\(trimmed[..<idx])…”"
    }
}

#Preview {
    NavigationStack {
        VersesChecklistView(bookName: "Genesis", chapterNumber: 1)
    }
}
