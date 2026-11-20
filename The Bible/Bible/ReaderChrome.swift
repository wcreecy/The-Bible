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

/// Small, semi-transparent chapter arrows in the bottom corners. They hide while scrolling and
/// fade a few seconds after it stops, since at rest they'd sit over the lines being read. They
/// come back whenever scrolling stops, and stay put for VoiceOver and Switch Control users.
struct ReaderChapterArrows: View {
    let scrollActivity: ReaderScrollActivity
    let onPrevious: () -> Void
    let onNext: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @State private var isRestingLong = false

    private static let restingDelay: Duration = .seconds(3)

    var body: some View {
        let isScrolling = scrollActivity.isScrolling
        let alwaysShown = voiceOverEnabled || switchControlEnabled
        let isHidden = isScrolling || (isRestingLong && !alwaysShown)

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
        .opacity(isHidden ? 0 : 1)
        .allowsHitTesting(!isHidden)
        .animation(.easeInOut(duration: 0.2), value: isScrolling)
        .animation(.easeInOut(duration: 0.4), value: isRestingLong)
        // Restarts each time scrolling starts or stops; only a full quiet stretch hides them.
        .task(id: isScrolling) {
            isRestingLong = false
            guard !isScrolling else { return }
            try? await Task.sleep(for: Self.restingDelay)
            guard !Task.isCancelled else { return }
            isRestingLong = true
        }
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

/// The reader's contextual tips, shown above the text while tips are turned on. Only one
/// shows at a time, so the chapter isn't pushed down by a stack of them: the first one not
/// yet dismissed. Dismissing it brings up the next.
struct ReaderTips: View {
    /// Whether the translation control sits in the toolbar rather than the "…" menu.
    let usesFullToolbar: Bool

    private enum Tip: String, CaseIterable {
        case translations = "reader.translations"
        case shortcuts = "reader.shortcuts"
        case statusIcons = "reader.statusIcons"
    }

    // Each tip's dismissal, watched so the next tip shows once the current one is dismissed.
    @AppStorage(AppStorageKey.contextualTipsResetGeneration) private var resetGeneration = 0
    @AppStorage(ContextualTipView.dismissedGenerationKey(for: Tip.translations.rawValue))
    private var translationsDismissed = -1
    @AppStorage(ContextualTipView.dismissedGenerationKey(for: Tip.shortcuts.rawValue))
    private var shortcutsDismissed = -1
    @AppStorage(ContextualTipView.dismissedGenerationKey(for: Tip.statusIcons.rawValue))
    private var statusIconsDismissed = -1

    private var currentTip: Tip? {
        Tip.allCases.first { tip in
            switch tip {
            // Only useful when there's more than one translation to choose from.
            case .translations:
                BibleTranslation.available.count > 1 && translationsDismissed != resetGeneration
            case .shortcuts:
                shortcutsDismissed != resetGeneration
            case .statusIcons:
                statusIconsDismissed != resetGeneration
            }
        }
    }

    var body: some View {
        if let tip = currentTip {
            tipView(tip)
                .id(tip)
                .padding(.bottom, 12)

            Divider()
        }
    }

    @ViewBuilder
    private func tipView(_ tip: Tip) -> some View {
        switch tip {
        case .translations:
            ContextualTipView(
                id: tip.rawValue,
                title: "Choose a translation",
                message: usesFullToolbar
                    ? "Tap the translation button at the top left to read another version. Your saved verses keep the translation they were saved in."
                    : "Tap the ellipsis button at the top right, then Translation, to read another version. Your saved verses keep the translation they were saved in.",
                systemImage: "character.book.closed"
            )
        case .shortcuts:
            ContextualTipView(
                id: tip.rawValue,
                title: "Reader shortcuts",
                message: "Tap a verse to keep your place. Tap it again for notes, highlights, favorites, and more. Swipe left or right to change chapters.",
                systemImage: "hand.draw"
            )
        case .statusIcons:
            ContextualTipView(
                id: tip.rawValue,
                title: "Understand verse icons",
                message: "Icons beside a verse's reference show your bookmark, favorites, notes, and Scripture connections. Tap a note or Scripture connection icon to open it. Change this in Settings › Bible Reader.",
                systemImage: "info.circle"
            )
        }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismissal.dismiss()
                    }
                }
            }
        }
        .environment(\.studySheetDismissal, dismissal)
    }
}
