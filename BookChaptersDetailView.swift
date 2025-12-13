import SwiftUI

struct ChapterDetailKey: Identifiable, Hashable {
    let bookName: String
    var id: String { bookName }
}

struct BookChaptersDetailView: View {
    let bookName: String

    @State private var visited: Set<String> = []
    @State private var selectedChapter: Int? = nil
    @State private var refreshID: UUID = UUID()

    private var book: Book? {
        BibleData.books.first(where: { $0.name == bookName })
    }
    private var chapterNumbers: [Int] {
        guard let b = book else { return [] }
        return b.chapters.map { $0.number }.sorted()
    }

    var body: some View {
        Group {
            if let b = book, !chapterNumbers.isEmpty {
                List {
                    Section {
                        ForEach(chapterNumbers, id: \.self) { chap in
                            let totalVerses = b.chapters.first(where: { $0.number == chap })?.verses.count ?? 0
                            let isRead = totalVerses > 0 && BibleStatsStore.shared.isChapterComplete(bookName: b.name, chapter: chap, totalVerses: totalVerses)

                            NavigationLink(destination: VersesChecklistView(bookName: b.name, chapterNumber: chap)) {
                                HStack(spacing: 8) {
                                    Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isRead ? .green : .secondary)
                                    Text("Chapter \(chap)")
                                        .strikethrough(isRead, color: .secondary)
                                        .foregroundStyle(isRead ? .secondary : .primary)
                                    Spacer()
                                    Button("Unread") {
                                        clearChapter(bookName: b.name, chapterNumber: chap)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .tint(.red)
                                    .disabled(!isRead)
                                    .accessibilityLabel("Mark Chapter \(chap) Unread")
                                }
                            }
                            .accessibilityLabel("Chapter \(chap) \(isRead ? "read" : "unread")")
                        }
                    } header: {
                        Text(b.name)
                    } footer: {
                        let readCount = chapterNumbers.reduce(0) { acc, chap in
                            let total = b.chapters.first(where: { $0.number == chap })?.verses.count ?? 0
                            let complete = total > 0 && BibleStatsStore.shared.isChapterComplete(bookName: b.name, chapter: chap, totalVerses: total)
                            return acc + (complete ? 1 : 0)
                        }
                        Text("\(readCount.formatted(.number.grouping(.automatic)))/\(chapterNumbers.count.formatted(.number.grouping(.automatic))) chapters read")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .id(refreshID)
            } else if book != nil {
                ContentUnavailableView("No chapters found", systemImage: "exclamationmark.triangle")
            } else {
                ContentUnavailableView("Book not found", systemImage: "exclamationmark.triangle")
            }
        }
        .onAppear {
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBibleReference)) { _ in
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chapterProgressChanged)) { _ in
            refreshID = UUID()
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
    }

    private func clearChapter(bookName: String, chapterNumber: Int) {
        BibleStatsStore.shared.saveSeenVerses([], bookName: bookName, chapter: chapterNumber)
        var v = BibleStatsStore.shared.loadVisitedChapters()
        v.remove("\(bookName):\(chapterNumber)")
        BibleStatsStore.shared.saveVisitedChapters(v)
        refreshID = UUID()
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
    }
}
