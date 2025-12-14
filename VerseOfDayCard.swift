import SwiftUI

struct VerseOfDayCard: View {
    @Binding var verseOfDay: HomeVerseRef?
    @Binding var verseOfDayPaused: Bool

    let isBibleStoreReady: Bool
    let nextRefreshDescription: String

    // Actions/closures provided by HomeView to keep behavior centralized
    let onRefresh: () -> Void
    let onCopy: (HomeVerseRef) -> Void
    let onShareText: (HomeVerseRef) -> String
    let isFavorited: (HomeVerseRef) -> Bool
    let onToggleFavorite: (HomeVerseRef) -> Void
    let onOpenReader: (HomeVerseRef) -> Void
    let onTogglePaused: () -> Void
    // NEW: Journal action
    let onOpenJournal: (HomeVerseRef) -> Void

    // Dynamic title/icon based on time of day
    let title: String
    let icon: String

    var body: some View {
        HeroCard(
            title: title,
            subtitle: nil,
            icon: icon,
            tint: .orange,
            trailingAccessory: {
                HStack(spacing: 8) {
                    if verseOfDayPaused {
                        Text("Paused")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.red.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                            .foregroundStyle(.red)
                    }
                    Button(action: onTogglePaused) {
                        Image(systemName: verseOfDayPaused ? "pause.circle.fill" : "pause.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(verseOfDayPaused ? Color.red : Color.blue)
                    .accessibilityLabel(verseOfDayPaused ? "Unpause Verse Refresh" : "Pause Verse Refresh")
                    .help(verseOfDayPaused ? "Unpause Verse Refresh" : "Pause Verse Refresh")
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let v = verseOfDay {
                    Text(v.verseText)
                        .font(.headline)
                        .italic()
                        .lineLimit(8)
                        .truncationMode(.tail)

                    Text("\(v.bookName) \(v.chapterNumber):\(v.verseNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        Button(action: onRefresh) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(verseOfDayPaused ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                        .font(.title3)
                        .help("Refresh")
                        .disabled(verseOfDayPaused)

                        Button(action: { onCopy(v) }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .help("Copy")

                        ShareLink(item: onShareText(v)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .font(.title3)
                        .help("Share")

                        Button(action: { onOpenJournal(v) }) {
                            Image(systemName: "book.closed")
                        }
                        .font(.title3)
                        .foregroundStyle(.brown)
                        .help("Journal")

                        Button(action: { onToggleFavorite(v) }) {
                            Image(systemName: isFavorited(v) ? "heart.fill" : "heart")
                                .foregroundStyle(.red)
                        }
                        .font(.title3)
                        .help("Favorite")
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
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                onOpenReader(v)
            }
            .contextMenu {
                if let v = verseOfDay {
                    Button {
                        onCopy(v)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    ShareLink(item: onShareText(v)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
