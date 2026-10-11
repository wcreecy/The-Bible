import SwiftUI

struct ChapterDetailKey: Identifiable, Hashable {
    let bookName: String
    var id: String { bookName }
}

private struct GenesisChapterSectionHeader: View {
    let chapterCount: Int

    var body: some View {
        HStack(spacing: 14) {
            GenesisCreationEmblem()

            VStack(alignment: .leading, spacing: 3) {
                Text("Genesis")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("The beginning")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(chapterCount) chapters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}

private struct GenesisCreationEmblem: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "sun.max.fill")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(.white)
                .offset(x: -7, y: -7)

            Image(systemName: "leaf.fill")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))
                .rotationEffect(.degrees(-25))
                .offset(x: 10, y: 10)
        }
        .frame(width: 60, height: 60)
        .accessibilityHidden(true)
    }
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
                        if b.name == "Genesis" {
                            GenesisChapterSectionHeader(chapterCount: chapterNumbers.count)
                        } else {
                            Text(b.name)
                        }
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
            // Also catches progress changes made while this screen was hidden.
            refreshID = UUID()
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
        .onChange(of: AppRouter.shared.latest) { _, request in
            if case .bibleReference = request?.destination {
                visited = BibleStatsStore.shared.loadVisitedChapters()
            }
        }
        .onNotification(.chapterProgressChanged) {
            refreshID = UUID()
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
    }

    private func clearChapter(bookName: String, chapterNumber: Int) {
        // Clears verses, visited state, and the completion date on every device.
        BibleStatsStore.shared.markChapterUnread(bookName: bookName, chapter: chapterNumber)
        refreshID = UUID()
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
    }
}
