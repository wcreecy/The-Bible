import SwiftUI

struct VersesView: View {
    let book: Book
    let chapter: Chapter
    @State private var previewVerse: Verse? = nil

    var body: some View {
        List {
            ForEach(chapter.verses) { verse in
                NavigationLink(destination: ReadingView(book: book, chapter: chapter, startVerse: verse.number)) {
                    HStack(spacing: 0) {
                        Text("Verse \(verse.number)")
                        Text(" of \(chapter.verses.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    previewVerse = verse
                }
            }
        }
        .sheet(item: $previewVerse) { verse in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(book.name) \(chapter.number):\(verse.number)")
                            .font(.title3).bold()
                        Text(verse.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                }
                .navigationTitle("Verse Preview")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") { previewVerse = nil }
                    }
                }
            }
        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        VersesView(book: BibleData.books.first!, chapter: BibleData.books.first!.chapters.first!)
    }
}
