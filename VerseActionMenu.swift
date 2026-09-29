import SwiftData
import SwiftUI
import UIKit

struct VerseActionReference: Hashable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String

    var shareText: String {
        "\(verseText)\n\(bookName) \(chapterNumber):\(verseNumber)"
    }
}

enum VerseActionPresentation {
    case buttons
    case menu
}

enum VerseActionFeedback {
    case addedFavorite
    case removedFavorite
    case bookmarked
    case pinned
    case unpinned
    case copied
}

@MainActor
struct VerseActionMenu: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @StateObject private var pinnedStore = PinnedVerseStore()
    @State private var persistenceFailure: PersistenceFailure?
    @State private var isBookmarked: Bool = false

    let verse: VerseActionReference
    var presentation: VerseActionPresentation = .menu
    var onFeedback: (VerseActionFeedback) -> Void = { _ in }

    private var isFavorite: Bool {
        favorites.contains {
            $0.bookName == verse.bookName &&
            $0.chapterNumber == verse.chapterNumber &&
            $0.verseNumber == verse.verseNumber
        }
    }

    private var isPinned: Bool {
        pinnedStore.isPinned(
            bookName: verse.bookName,
            chapter: verse.chapterNumber,
            verse: verse.verseNumber
        )
    }

    var body: some View {
        actionPresentation
            .task(id: verse) {
                await pinnedStore.load()
                let defaults = UserDefaults(suiteName: "group.bible.app")
                isBookmarked = defaults?.string(forKey: "lastReadBook") == verse.bookName &&
                    defaults?.integer(forKey: "lastReadChapter") == verse.chapterNumber &&
                    defaults?.integer(forKey: "lastReadVerse") == verse.verseNumber
            }
            .persistenceFailureAlert(failure: $persistenceFailure)
    }

    @ViewBuilder
    private var actionPresentation: some View {
        switch presentation {
        case .buttons:
            HStack(spacing: 24) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")

                Button(action: bookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(isBookmarked ? "Continue Reading is set here" : "Set as Continue Reading")

                Button(action: togglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(isPinned ? "Unpin from Widget" : "Pin to Widget")

                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                }
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Copy")

                ShareLink(item: verse.shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Share")
            }
            .font(.title3)
            .buttonStyle(.plain)

        case .menu:
            Menu {
                Button(action: toggleFavorite) {
                    Label(
                        isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: isFavorite ? "heart.fill" : "heart"
                    )
                }

                Button(action: bookmark) {
                    Label(
                        isBookmarked ? "Continue Reading Set Here" : "Set as Continue Reading",
                        systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }

                Button(action: togglePin) {
                    Label(
                        isPinned ? "Unpin from Widget" : "Pin to Widget",
                        systemImage: isPinned ? "pin.fill" : "pin"
                    )
                }

                Button(action: copy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                ShareLink(item: verse.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Verse actions")
        }
    }

    private func toggleFavorite() {
        if let existing = favorites.first(where: {
            $0.bookName == verse.bookName &&
            $0.chapterNumber == verse.chapterNumber &&
            $0.verseNumber == verse.verseNumber
        }) {
            ModelContextPersistence.perform(
                in: modelContext,
                operation: {
                    modelContext.delete(existing)
                    try modelContext.save()
                },
                onSuccess: {
                    Haptics.selection()
                    onFeedback(.removedFavorite)
                },
                onFailure: { persistenceFailure = $0 }
            )
        } else {
            ModelContextPersistence.perform(
                in: modelContext,
                operation: {
                    modelContext.insert(
                        Favorite(
                            bookName: verse.bookName,
                            chapterNumber: verse.chapterNumber,
                            verseNumber: verse.verseNumber,
                            verseText: verse.verseText
                        )
                    )
                    try modelContext.save()
                },
                onSuccess: {
                    Haptics.success()
                    onFeedback(.addedFavorite)
                },
                onFailure: { persistenceFailure = $0 }
            )
        }
    }

    private func bookmark() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                try ReadingProgressStore.save(
                    in: modelContext,
                    bookName: verse.bookName,
                    chapter: verse.chapterNumber,
                    verse: verse.verseNumber
                )
            },
            onSuccess: {
                VerseActionPersistence.mirrorBookmark(verse)
                isBookmarked = true
                Haptics.success()
                onFeedback(.bookmarked)
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func togglePin() {
        Task { @MainActor in
            if isPinned {
                await pinnedStore.clear()
                onFeedback(.unpinned)
            } else {
                await pinnedStore.set(
                    bookName: verse.bookName,
                    chapter: verse.chapterNumber,
                    verse: verse.verseNumber,
                    text: verse.verseText
                )
                onFeedback(.pinned)
            }
            Haptics.success()
        }
    }

    private func copy() {
        UIPasteboard.general.string = verse.shareText
        Haptics.selection()
        onFeedback(.copied)
    }
}

@MainActor
private enum VerseActionPersistence {
    static func mirrorBookmark(_ verse: VerseActionReference) {
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set(verse.bookName, forKey: "lastReadBook")
            shared.set(verse.chapterNumber, forKey: "lastReadChapter")
            shared.set(verse.verseNumber, forKey: "lastReadVerse")
            shared.set(verse.verseText, forKey: "lastReadText")
        }

        let ubiquitousStore = NSUbiquitousKeyValueStore.default
        ubiquitousStore.set(verse.bookName, forKey: "lastReadBook")
        ubiquitousStore.set(Int64(verse.chapterNumber), forKey: "lastReadChapter")
        ubiquitousStore.set(Int64(verse.verseNumber), forKey: "lastReadVerse")
        ubiquitousStore.set(verse.verseText, forKey: "lastReadText")
        ubiquitousStore.synchronize()

        BibleStatsStore.shared.saveLastRead(
            bookName: verse.bookName,
            chapterNumber: verse.chapterNumber,
            date: Date()
        )
        ReadingTimeTracker.shared.setCurrentLocation(
            bookName: verse.bookName,
            chapter: verse.chapterNumber
        )
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
    }
}
