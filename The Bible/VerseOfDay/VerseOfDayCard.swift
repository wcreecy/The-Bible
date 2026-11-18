import SwiftUI

struct VerseOfDayCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var verseActionPresentation: VerseActionPresentation {
        dynamicTypeSize.isAccessibilitySize || horizontalSizeClass == .compact || columnCount == 1
            ? .cardActions
            : .buttons
    }

    @Binding var verseOfDay: HomeVerseRef?
    @Binding var verseOfDayPaused: Bool

    let isBibleStoreReady: Bool
    let nextRefreshDescription: String
    let canUndoRefresh: Bool

    // Actions/closures provided by HomeView to keep behavior centralized
    let onRefresh: () -> Void
    let onUndoRefresh: () -> Void
    let onVerseActionFeedback: (VerseActionFeedback) -> Void
    let onOpenReader: (HomeVerseRef) -> Void
    let onTogglePaused: () -> Void
    // Dynamic title/icon based on time of day
    let title: String
    let icon: String
    /// How many iPad dashboard columns the card covers; wider cards set shorter verses larger.
    var columnCount = 1

    /// A wide card leaves a short verse as one sparse line, so it gets a larger text style:
    /// the shorter the verse and the wider the card, the larger. Long verses stay close to
    /// the regular size so they don't run past the line limit.
    private func verseFont(for text: String) -> Font {
        guard columnCount > 1 else { return .headline }
        let isFullWidth = columnCount >= 3
        switch text.count {
        case ..<100: return isFullWidth ? .title : .title2
        case ..<200: return isFullWidth ? .title2 : .title3
        default: return isFullWidth ? .title3 : .headline
        }
    }

    var body: some View {
        HeroCard(
            title: title,
            subtitle: nil,
            icon: icon,
            tint: .orange,
            trailingAccessory: {
                HStack(spacing: 8) {
                    if verseOfDayPaused {
                        Text("Pinned")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
                            .foregroundStyle(.orange)
                    }
                    Button(action: onTogglePaused) {
                        Image(systemName: verseOfDayPaused ? "pin.circle.fill" : "pin.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(verseOfDayPaused ? Color.orange : Color.accentColor)
                    .accessibilityLabel(verseOfDayPaused ? "Unpin Verse" : "Pin Verse")
                    .help(verseOfDayPaused ? "Unpin to resume automatic refresh" : "Pin to stop automatic refresh")
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let v = verseOfDay {
                    Text(v.verseText)
                        .font(verseFont(for: v.verseText))
                        .fontWeight(.semibold)
                        .italic()
                        .lineLimit(8)
                        .truncationMode(.tail)
                        .contentTransition(.opacity)

                    Text("\(v.bookName) \(v.chapterNumber):\(v.verseNumber) · \(BibleRepository.shared.activeTranslation.abbreviation)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)

                    HStack(spacing: 24) {
                        // Always laid out, so the buttons beside it don't move when it appears.
                        Button(action: onUndoRefresh) {
                            Label("Undo Verse Refresh", systemImage: "arrow.uturn.backward")
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.orange)
                        .font(.title3)
                        .help("Return to the previous verse")
                        .opacity(canUndoRefresh ? 1 : 0)
                        .disabled(!canUndoRefresh)
                        .accessibilityHidden(!canUndoRefresh)
                        .animation(.easeInOut(duration: 0.2), value: canUndoRefresh)

                        // Not disabled while pinned: tapping it explains why nothing changes.
                        Button(action: onRefresh) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(verseOfDayPaused ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                        .font(.title3)
                        .help(verseOfDayPaused ? "Unpin to refresh" : "Refresh")
                        .accessibilityHint(verseOfDayPaused ? "Unpin the verse first" : "Shows a different verse")

                        VerseActionMenu(
                            verse: VerseActionReference(
                                bookName: v.bookName,
                                chapterNumber: v.chapterNumber,
                                verseNumber: v.verseNumber,
                                verseText: v.verseText
                            ),
                            presentation: verseActionPresentation,
                            // The color strip is for the reader; Home keeps the card calm.
                            showsHighlightColors: false,
                            onFeedback: onVerseActionFeedback
                        )
                        .help("Verse actions")
                    }
                    .frame(maxWidth: .infinity)

                    Text(nextRefreshDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        if !isBibleStoreReady {
                            Text("Loading verse data…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .redacted(reason: .placeholder)
                        } else {
                            Text("Verse will refresh automatically at your selected times.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(nextRefreshDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard let v = verseOfDay else { return }
                Haptics.selection()
                onOpenReader(v)
            }
            // Squeezing or double-tapping the Apple Pencil on the verse offers the card's actions.
            .pencilPopover { dismiss in
                VerseOfDayPencilActions(
                    verse: verseOfDay,
                    isPaused: verseOfDayPaused,
                    canUndoRefresh: canUndoRefresh,
                    onRefresh: onRefresh,
                    onUndoRefresh: onUndoRefresh,
                    onTogglePaused: onTogglePaused,
                    onOpenReader: onOpenReader,
                    onVerseActionFeedback: onVerseActionFeedback,
                    dismiss: dismiss
                )
            }
        }
    }
}

/// The Verse of the Day card's actions, shown at the Apple Pencil tip.
private struct VerseOfDayPencilActions: View {
    let verse: HomeVerseRef?
    let isPaused: Bool
    let canUndoRefresh: Bool
    let onRefresh: () -> Void
    let onUndoRefresh: () -> Void
    let onTogglePaused: () -> Void
    let onOpenReader: (HomeVerseRef) -> Void
    let onVerseActionFeedback: (VerseActionFeedback) -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let verse {
                Text("\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)")
                    .font(.headline)

                // Favorite, Share and the rest of a verse's actions.
                VerseActionMenu(
                    verse: VerseActionReference(
                        bookName: verse.bookName,
                        chapterNumber: verse.chapterNumber,
                        verseNumber: verse.verseNumber,
                        verseText: verse.verseText
                    ),
                    presentation: .cardActions,
                    showsHighlightColors: false,
                    onFeedback: onVerseActionFeedback
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
            }

            action("Refresh", systemImage: "arrow.clockwise", isDimmed: isPaused, perform: onRefresh)
            if canUndoRefresh {
                action("Previous Verse", systemImage: "arrow.uturn.backward", perform: onUndoRefresh)
            }
            action(isPaused ? "Unpin Verse" : "Pin Verse", systemImage: isPaused ? "pin.slash" : "pin", perform: onTogglePaused)
            if let verse {
                action("Open in Bible", systemImage: "book") { onOpenReader(verse) }
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func action(
        _ title: LocalizedStringKey,
        systemImage: String,
        isDimmed: Bool = false,
        perform: @escaping () -> Void
    ) -> some View {
        Button {
            dismiss()
            perform()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .opacity(isDimmed ? 0.6 : 1)
    }
}
