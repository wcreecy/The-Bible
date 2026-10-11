import SwiftUI
import SwiftData
import UIKit

struct VersesView: View {
    let book: Book
    let chapter: Chapter
    @Environment(NavigationCoordinator.self) private var coordinator
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage(RedLetterText.suppliedWordsInItalicsKey) private var italicizesSuppliedWords = false

    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var toastSymbol: String = "checkmark.circle.fill"
    @State private var toastTint: Color = .blue

    @State private var previewVerse: Verse? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if contextualTipsEnabled {
                    ContextualTipView(
                        id: "verses.actions",
                        title: "More verse actions",
                        message: "Press and hold a verse to preview it, then favorite, bookmark, copy, or pin it to the Home Screen widget.",
                        systemImage: "hand.tap"
                    )
                    .padding(.bottom, 12)

                    Divider()
                }

                ForEach(chapter.verses) { verse in
                    NavigationLink(
                        value: Route.reader(book: book, chapter: chapter, startVerse: verse.number)
                    ) {
                        HStack(spacing: 0) {
                            Text("Verse \(verse.number)")
                            Text(" of \(chapter.verses.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: AppDesignMetrics.selectionRowMinHeight)
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                    .highPriorityGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
                                previewVerse = verse
                            }
                    )

                    if verse.number != chapter.verses.last?.number {
                        Divider()
                    }
                }
            }
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .background(AppBackgroundView(tab: .bible))
        .sheet(item: $previewVerse) { verse in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(book.name) \(chapter.number):\(verse.number)")
                            .font(.title3).bold()
                        Text(verse.attributedText(italicizingSuppliedWords: italicizesSuppliedWords))
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                }
                .navigationTitle("Verse Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { previewVerse = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Open") {
                            previewVerse = nil
                            if let book = BibleData.books.first(where: { $0.name == self.book.name }), let chapter = book.chapters.first(where: { $0.number == self.chapter.number }) {
                                coordinator.push(.reader(book: book, chapter: chapter, startVerse: verse.number))
                            }
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        VerseActionMenu(
                            verse: VerseActionReference(
                                bookName: book.name,
                                chapterNumber: chapter.number,
                                verseNumber: verse.number,
                                verseText: verse.text
                            ),
                            presentation: .buttons,
                            onFeedback: handleVerseActionFeedback
                        )
                    }
                }
            }
            .appToast(isPresented: $showToast, symbol: toastSymbol, text: toastText, tint: toastTint)
        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleVerseActionFeedback(_ feedback: VerseActionFeedback) {
        toastSymbol = feedback.toastSymbol
        toastTint = feedback.toastTint
        toastText = feedback.toastText
        withAnimation(.spring()) { showToast = true }
    }

}

#Preview {
    NavigationStack {
        VersesView(book: BibleData.books.first!, chapter: BibleData.books.first!.chapters.first!)
            .environment(NavigationCoordinator())
    }
}
