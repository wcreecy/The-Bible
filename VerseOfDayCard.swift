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
        ZStack {
            // Background image under the entire card, clipped to the card shape
            GeometryReader { geo in
                Image("river-bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay(Color.black.opacity(0.25)) // Slightly darker overlay for even better legibility
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
            }
            .allowsHitTesting(false)

            HeroCard(
                title: title,
                subtitle: nil,
                icon: icon,
                tint: .orange,
                backgroundColor: .clear,
                trailingAccessory: {
                    HStack(spacing: 8) {
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(verseOfDayPaused ? Color.secondary : Color.green)
                        .font(.title3)
                        .help("Refresh")
                        .disabled(verseOfDayPaused)
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

                        if verseOfDayPaused {
                            Text("Paused")
                                .font(.caption2).bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.red.opacity(0.15)))
                                .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                                .foregroundStyle(.red)
                                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        }
                        Button(action: onTogglePaused) {
                            Image(systemName: verseOfDayPaused ? "pause.circle.fill" : "pause.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(verseOfDayPaused ? Color.red : Color.blue)
                        .accessibilityLabel(verseOfDayPaused ? "Unpause Verse Refresh" : "Pause Verse Refresh")
                        .help(verseOfDayPaused ? "Unpause Verse Refresh" : "Pause Verse Refresh")
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    }
                }
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    if let v = verseOfDay {
                        Text(v.verseText)
                            .font(.subheadline)
                            .italic()
                            .lineLimit(8)
                            .truncationMode(.tail)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

                        Text("\(v.bookName) \(v.chapterNumber):\(v.verseNumber)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

                        HStack(spacing: 20) {
                            Button(action: { onCopy(v) }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .labelStyle(.iconOnly)
                            .font(.body)
                            .help("Copy")
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

                            ShareLink(item: onShareText(v)) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .font(.body)
                            .help("Share")
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

                            Button(action: { onOpenJournal(v) }) {
                                Image(systemName: "book.closed")
                            }
                            .font(.body)
                            .foregroundStyle(.brown)
                            .help("Journal")
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

                            Button(action: { onToggleFavorite(v) }) {
                                Image(systemName: isFavorited(v) ? "heart.fill" : "heart")
                                    .foregroundStyle(.red)
                            }
                            .font(.body)
                            .help("Favorite")
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        }
                        .frame(maxWidth: .infinity)

                        Text(nextRefreshDescription)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 2)
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            if !isBibleStoreReady {
                                Text("Loading verse data…")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .redacted(reason: .placeholder)
                                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                            } else {
                                Text("Verse will refresh automatically at your selected times.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                            }
                            Text(nextRefreshDescription)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
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
            .foregroundStyle(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
