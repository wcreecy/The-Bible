import SwiftUI
import UIKit

// Small pieces of reader chrome used by ReadingView: the display popover, the floating
// chapter arrows, and the chapter slide-in values.

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
