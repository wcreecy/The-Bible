import SwiftUI

struct ResumeReadingCard: View {
    struct ReadingPoint: Equatable {
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        let verseText: String
        let savedAt: Date

        init(bookmark: Bookmark) {
            bookName = bookmark.bookName
            chapterNumber = bookmark.chapterNumber
            verseNumber = bookmark.verseNumber
            verseText = bookmark.verseText
            savedAt = bookmark.createdAt
        }

        init(bookName: String, chapterNumber: Int, verseNumber: Int, verseText: String, savedAt: Date) {
            self.bookName = bookName
            self.chapterNumber = chapterNumber
            self.verseNumber = verseNumber
            self.verseText = verseText
            self.savedAt = savedAt
        }
    }

    /// The saved passage to return to. Debug previews provide an in-memory value here.
    let readingPoint: ReadingPoint?
    let usesCompactLayout: Bool
    let onOpenReference: (ReadingPoint) -> Void
    let onStartReading: () -> Void
    let onChoosePassage: (String, Int, Int) -> Void

    @State private var showsScripturePicker = false

    var body: some View {
        Group {
            if let readingPoint {
            let verseText = readingPoint.verseText
            Button(action: { onOpenReference(readingPoint) }) {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                            Text("Resume Reading")
                                .font(.headline)
                                .bold()
                        }
                        Spacer()
                        Label("Resume", systemImage: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .labelStyle(.titleAndIcon)
                            .accessibilityHidden(true)
                    }

                    if usesCompactLayout {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 0) {
                                Text("\(readingPoint.bookName) \(readingPoint.chapterNumber):\(readingPoint.verseNumber)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .layoutPriority(1)

                                if !verseText.isEmpty {
                                    Text(" “\(verseText)”")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }

                            readingRecency(for: readingPoint.savedAt)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 0) {
                                Text("\(readingPoint.bookName) \(readingPoint.chapterNumber):\(readingPoint.verseNumber)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .layoutPriority(1)

                                if !verseText.isEmpty {
                                    Text(" “\(verseText)”")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }

                            readingRecency(for: readingPoint.savedAt)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            } else {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: onStartReading) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "book.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                Text("Start with Genesis")
                                    .font(.headline)
                                    .bold()
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Text("Begin at Genesis 1, or choose another passage.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("Choose a passage") {
                            showsScripturePicker = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .sheet(isPresented: $showsScripturePicker) {
            NavigationStack {
                ScripturePickerView(
                    initialBook: "Genesis",
                    initialChapter: 1,
                    initialVerse: 1
                ) { bookName, chapterNumber, verseNumber in
                    onChoosePassage(bookName, chapterNumber, verseNumber)
                }
            }
        }
    }

    @ViewBuilder
    private func readingRecency(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(recencyText(for: date))
                .font(.caption)
                .foregroundStyle(.secondary)

            if ResumeReadingRecency.isOld(date) {
                Text("Pick up where you left off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func recencyText(for date: Date) -> String {
        ResumeReadingRecency.text(for: date)
    }
}

enum ResumeReadingRecency {
    static func text(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "Saved today")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Saved yesterday")
        }
        return String(localized: "Saved \(date.formatted(date: .abbreviated, time: .omitted))")
    }

    static func isOld(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let cutoff = calendar.date(byAdding: .day, value: -14, to: now) else { return false }
        return date < cutoff
    }
}

#Preview("Saved today") {
    ResumeReadingCard(
        readingPoint: .init(
            bookName: "Matthew",
            chapterNumber: 6,
            verseNumber: 9,
            verseText: "After this manner therefore pray ye: Our Father which art in heaven, Hallowed be thy name.",
            savedAt: .now
        ),
        usesCompactLayout: true,
        onOpenReference: { _ in },
        onStartReading: {},
        onChoosePassage: { _, _, _ in }
    )
    .padding()
}

#Preview("Saved yesterday") {
    ResumeReadingCard(
        readingPoint: .init(
            bookName: "Matthew",
            chapterNumber: 6,
            verseNumber: 9,
            verseText: "After this manner therefore pray ye: Our Father which art in heaven, Hallowed be thy name.",
            savedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        ),
        usesCompactLayout: false,
        onOpenReference: { _ in },
        onStartReading: {},
        onChoosePassage: { _, _, _ in }
    )
    .padding()
}

#Preview("Saved three weeks ago") {
    ResumeReadingCard(
        readingPoint: .init(
            bookName: "Matthew",
            chapterNumber: 6,
            verseNumber: 9,
            verseText: "After this manner therefore pray ye: Our Father which art in heaven, Hallowed be thy name.",
            savedAt: Calendar.current.date(byAdding: .day, value: -21, to: .now) ?? .now
        ),
        usesCompactLayout: false,
        onOpenReference: { _ in },
        onStartReading: {},
        onChoosePassage: { _, _, _ in }
    )
    .padding()
}
