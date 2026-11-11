import SwiftData
import SwiftUI

struct VerseActionReference: Hashable, Identifiable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    /// The translation `verseText` is in. A saved verse passes the one it was saved in.
    var translation: BibleTranslation = BibleRepository.shared.activeTranslation

    var id: String {
        "\(bookName)|\(chapterNumber)|\(verseNumber)|\(verseText)"
    }

    var shareText: String {
        "\(verseText)\n\(bookName) \(chapterNumber):\(verseNumber) \(translation.abbreviation)"
    }
}

enum VerseActionPresentation {
    case buttons
    case focus
    case menu
    /// Favorite and share sit on the card; everything else is in a "more" menu.
    case cardActions
}

enum VerseActionFeedback {
    case addedFavorite
    case removedFavorite
    case bookmarked
    case removedBookmark
    case pinned
    case unpinned
    case copied

    // Toast shown for each action, shared by every screen that hosts a verse menu.

    var toastSymbol: String {
        switch self {
        case .addedFavorite: "heart.fill"
        case .removedFavorite: "heart.slash"
        case .bookmarked: "bookmark.fill"
        case .removedBookmark: "bookmark"
        case .pinned: "pin.fill"
        case .unpinned: "pin"
        case .copied: "doc.on.doc"
        }
    }

    var toastText: String {
        switch self {
        case .addedFavorite: String(localized: "Added to Favorites")
        case .removedFavorite: String(localized: "Removed Favorite")
        case .bookmarked: String(localized: "Bookmarked")
        case .removedBookmark: String(localized: "Removed Bookmark")
        case .pinned: String(localized: "Pinned to Widget")
        case .unpinned: String(localized: "Unpinned from Widget")
        case .copied: String(localized: "Copied to Clipboard")
        }
    }

    var toastTint: Color {
        switch self {
        case .addedFavorite: .pink
        case .removedFavorite, .removedBookmark: .secondary
        case .bookmarked: .bookmarkTint
        case .copied: .accentColor
        case .pinned, .unpinned: .red
        }
    }
}

/// Passes menu feedback up to the screen's toast. It is a class so the environment value
/// stays the same object, and the menus below aren't redrawn each time the toast changes.
final class VerseActionFeedbackRelay {
    var send: (VerseActionFeedback) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Receives feedback from any verse menu below that wasn't given its own `onFeedback`.
    @Entry var verseActionFeedback: VerseActionFeedbackRelay? = nil
}

/// Drives the toast a screen shows after a verse action. Keep one as `@State` and attach
/// `.verseActionToast($state)` to the screen.
struct VerseActionToastState {
    fileprivate(set) var feedback: VerseActionFeedback = .copied
    fileprivate(set) var isPresented = false

    fileprivate mutating func show(_ feedback: VerseActionFeedback) {
        self.feedback = feedback
        withAnimation(.spring()) { isPresented = true }
    }
}

private struct VerseActionToastModifier: ViewModifier {
    @Binding var state: VerseActionToastState
    let bottomPadding: CGFloat
    @State private var relay = VerseActionFeedbackRelay()

    func body(content: Content) -> some View {
        content
            .environment(\.verseActionFeedback, relay)
            .onAppear { relay.send = { state.show($0) } }
            .appToast(
                isPresented: $state.isPresented,
                symbol: state.feedback.toastSymbol,
                text: state.feedback.toastText,
                tint: state.feedback.toastTint,
                bottomPadding: bottomPadding
            )
    }
}

extension View {
    /// Shows a toast for the actions of every verse menu in this view that doesn't pass its
    /// own `onFeedback`.
    func verseActionToast(_ state: Binding<VerseActionToastState>, bottomPadding: CGFloat = 20) -> some View {
        modifier(VerseActionToastModifier(state: state, bottomPadding: bottomPadding))
    }
}

/// The saved items a verse menu reads to show its state (favorited, bookmarked, noted).
struct SavedVerseCollections {
    let favorites: [Favorite]
    let notes: [VerseNote]
    let userNotes: [UserNote]
    let bookmarks: [Bookmark]
}

