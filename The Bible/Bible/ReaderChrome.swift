import SwiftUI
import UIKit

// Small pieces of reader chrome used by ReadingView: the display popover, the floating
// chapter arrows, the chapter slide-in values, the tips, the links to neighboring chapters,
// and the Chapter Insights sheet (shared with Focus Mode).

/// The values a new chapter animates from as it slides in.
struct ChapterSlide {
    var offset: CGFloat = 0
    var opacity: Double = 1
}

/// Text size and display choices. A popover stays open while the slider moves, which the
/// toolbar menu it replaces couldn't do.
struct ReaderDisplayOptions: View {
    @Binding var fontSize: Double
    @Binding var showsFullReferences: Bool

    private static let defaultFontSize = 17.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "textformat.size.smaller")
                    .accessibilityHidden(true)
                Slider(value: $fontSize, in: 12...30, step: 1) {
                    Text("Text Size")
                }
                .accessibilityValue(Text("\(Int(fontSize)) points"))
                Image(systemName: "textformat.size.larger")
                    .accessibilityHidden(true)
            }

            if fontSize != Self.defaultFontSize {
                Button("Reset Text Size") {
                    fontSize = Self.defaultFontSize
                }
            }

            Divider()

            Toggle("Full reference on each verse", isOn: $showsFullReferences)
        }
        .padding()
        .frame(minWidth: 300)
        .presentationCompactAdaptation(.popover)
    }
}

extension View {
    @ViewBuilder
    func readerCardWidth() -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            containerRelativeFrame(.horizontal)
        } else {
            self
        }
    }
}

/// Whether the reader's text is moving. A reference type, so writing it from the scroll
/// view doesn't invalidate the reader; only views that read it redraw.
@MainActor
@Observable
final class ReaderScrollActivity {
    var isScrolling = false
}

/// Small, semi-transparent chapter arrows in the bottom corners, hidden while scrolling.
struct ReaderChapterArrows: View {
    let scrollActivity: ReaderScrollActivity
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        let isScrolling = scrollActivity.isScrolling

        VStack {
            Spacer()
            HStack {
                arrow("chevron.left", label: "Previous chapter", action: onPrevious)
                    .padding(.leading, 12)

                Spacer()

                arrow("chevron.right", label: "Next chapter", action: onNext)
                    .padding(.trailing, 12)
            }
            .padding(.bottom, 10)
        }
        .opacity(isScrolling ? 0 : 1)
        .allowsHitTesting(!isScrolling)
        .animation(.easeInOut(duration: 0.2), value: isScrolling)
    }

    private func arrow(_ systemImage: String, label: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44) // hit target
                .background(.ultraThinMaterial, in: Circle())
                .opacity(0.7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// The reader's contextual tips, shown above the text while tips are turned on.
struct ReaderTips: View {
    /// Whether the translation control sits in the toolbar rather than the "…" menu.
    let usesFullToolbar: Bool

    var body: some View {
        if BibleTranslation.available.count > 1 {
            ContextualTipView(
                id: "reader.translations",
                title: "Choose a translation",
                message: usesFullToolbar
                    ? "Tap the translation button at the top left to read another version. Your saved verses keep the translation they were saved in."
                    : "Tap the ellipsis button at the top right, then Translation, to read another version. Your saved verses keep the translation they were saved in.",
                systemImage: "character.book.closed"
            )
            .padding(.bottom, 12)
        }

        ContextualTipView(
            id: "reader.shortcuts",
            title: "Reader shortcuts",
            message: "Swipe left or right to change chapters. Press and hold a verse for notes, highlights, favorites, and more.",
            systemImage: "hand.draw"
        )
        .padding(.bottom, 12)

        ContextualTipView(
            id: "reader.statusIcons",
            title: "Understand verse icons",
            message: "Icons beside a verse's reference show your bookmark, favorites, notes, and Scripture connections. Tap a note or Scripture connection icon to open it. Change this in Settings › Bible Reader.",
            systemImage: "info.circle"
        )
        .padding(.bottom, 12)

        Divider()
    }
}

/// Quiet links to the chapters either side, named so it's clear where each goes.
struct ReaderChapterLinks: View {
    let previousTitle: String?
    let nextTitle: String?
    /// Called with `true` for the next chapter, `false` for the previous one.
    let onSelect: (_ forward: Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let previousTitle {
                link(title: previousTitle, forward: false)
            }
            Spacer(minLength: 0)
            if let nextTitle {
                link(title: nextTitle, forward: true)
            }
        }
    }

    private func link(title: String, forward: Bool) -> some View {
        Button {
            onSelect(forward)
        } label: {
            HStack(spacing: 4) {
                if !forward {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                if forward {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(forward ? "Continue to \(title)" : "Back to \(title)")
        .accessibilityHint(forward ? "Opens the next chapter" : "Opens the previous chapter")
    }
}

/// Chapter Insights for the chapter open in the reader or Focus Mode, with a Done button.
struct ReaderChapterInsightsSheet: View {
    let bookName: String
    let chapterNumber: Int
    let dismissal: StudySheetDismissal

    var body: some View {
        NavigationStack {
            ChapterInsightsView(
                bookName: bookName,
                chapterNumber: chapterNumber,
                openedFromReader: true
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismissal.dismiss()
                    }
                }
            }
        }
        .environment(\.studySheetDismissal, dismissal)
    }
}
