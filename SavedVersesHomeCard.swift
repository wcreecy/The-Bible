import SwiftUI

struct SavedVerseHomePreview: Equatable {
    enum Kind: String, Equatable {
        case favorite
        case highlight

        fileprivate var sortOrder: Int {
            switch self {
            case .favorite: 0
            case .highlight: 1
            }
        }
    }

    /// The verse chosen for a given day, saved so the card doesn't change when
    /// verses are added or removed later that day.
    struct DailyPin: Equatable {
        let id: String
        let day: Int
    }

    let reference: String
    let text: String
    let kind: Kind
    let date: Date
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let highlightColor: VerseHighlightColor?

    /// Identifies the saved item; a verse can be both a favorite and a highlight.
    var pinID: String {
        "\(kind.rawValue)|\(bookName)|\(chapterNumber)|\(verseNumber)"
    }

    /// Chooses a stable saved verse for the local day.
    /// Today's pinned verse wins while it's still saved. Otherwise the most recently
    /// saved item is skipped when another saved verse is available.
    static func dailyPreview(
        from previews: [SavedVerseHomePreview],
        on date: Date = .now,
        calendar: Calendar = .current,
        rotationOffset: Int = 0,
        pinned: DailyPin? = nil
    ) -> SavedVerseHomePreview? {
        if let pinned,
           pinned.day == dayIndex(for: date, calendar: calendar),
           let pinnedPreview = previews.first(where: { $0.pinID == pinned.id }) {
            return pinnedPreview
        }

        let sortedPreviews = previews.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }
            if lhs.reference != rhs.reference {
                return lhs.reference < rhs.reference
            }
            return lhs.kind.sortOrder < rhs.kind.sortOrder
        }

        let eligiblePreviews = sortedPreviews.count > 1
            ? Array(sortedPreviews.dropLast())
            : sortedPreviews
        guard let index = dailyIndex(
            itemCount: eligiblePreviews.count,
            on: date,
            calendar: calendar,
            rotationOffset: rotationOffset
        ) else {
            return nil
        }

        return eligiblePreviews[index]
    }

    /// Returns a stable position in a collection for the local day.
    static func dailyIndex(
        itemCount: Int,
        on date: Date = .now,
        calendar: Calendar = .current,
        rotationOffset: Int = 0
    ) -> Int? {
        guard itemCount > 0 else { return nil }

        let dayIndex = dayIndex(for: date, calendar: calendar)
        return (dayIndex % itemCount + rotationOffset % itemCount + itemCount) % itemCount
    }

    /// Counts calendar days from a fixed date, so the day changes at local midnight.
    static func dayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        let referenceDate = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)) ?? .distantPast
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
    }
}

enum SavedVersesHomeCardSubtitle {
    /// Lists only the non-zero counts, or nil when nothing is saved yet.
    static func text(favoriteCount: Int, highlightCount: Int) -> String? {
        var parts: [String] = []
        if favoriteCount > 0 {
            parts.append(inflected(AttributedString(localized: "^[\(favoriteCount) favorite](inflect: true)")))
        }
        if highlightCount > 0 {
            parts.append(inflected(AttributedString(localized: "^[\(highlightCount) highlight](inflect: true)")))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func inflected(_ string: AttributedString) -> String {
        String(string.characters)
    }
}

struct SavedVersesHomeCard: View {
    let preview: SavedVerseHomePreview?
    let favoriteCount: Int
    let highlightCount: Int
    let onOpenSavedVerses: () -> Void
    let onRefresh: () -> Void
    let onOpenVerse: (SavedVerseHomePreview) -> Void

    private var subtitle: String? {
        SavedVersesHomeCardSubtitle.text(
            favoriteCount: favoriteCount,
            highlightCount: highlightCount
        )
    }

    var body: some View {
        HeroCard(
            title: "Saved Verses",
            subtitle: subtitle,
            icon: "heart.text.clipboard",
            tint: .pink,
            trailingAccessory: {
                HStack(spacing: 8) {
#if DEBUG
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Refresh saved verse")
#endif

                    Button("View All", action: onOpenSavedVerses)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .accessibilityLabel("View all saved verses")
                }
            }
        ) {
            SavedVersesHomeCardContent(
                preview: preview,
                onOpenSavedVerses: onOpenSavedVerses,
                onOpenVerse: onOpenVerse
            )
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SavedVersesHomeCardContent: View {
    let preview: SavedVerseHomePreview?
    let onOpenSavedVerses: () -> Void
    let onOpenVerse: (SavedVerseHomePreview) -> Void

    var body: some View {
        if let preview {
            Button {
                onOpenVerse(preview)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 6) {
                        if preview.kind == .highlight, let highlightColor = preview.highlightColor {
                            Text("From your \(Text("Highlighted Verses").foregroundStyle(highlightColor.color))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else if preview.kind == .highlight {
                            Text("From your Highlighted Verses")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("From your Favorites")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(preview.reference)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("“\(preview.text)”")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.leading, preview.highlightColor == nil ? 0 : 14)
                    .padding(.trailing, preview.highlightColor == nil ? 0 : 10)
                    .padding(.vertical, preview.highlightColor == nil ? 0 : 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(preview.highlightColor?.color.opacity(0.10) ?? .clear)
                    )
                    .overlay(alignment: .leading) {
                        if let highlightColor = preview.highlightColor {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(highlightColor.color)
                                .frame(width: 4)
                                .accessibilityHidden(true)
                        }
                    }

                    HStack {
                        Spacer()

                        if preview.kind == .favorite {
                            Text("Saved on \(preview.date, format: .dateTime.month(.abbreviated).day().year())")
                        } else {
                            Text("Highlighted on \(preview.date, format: .dateTime.month(.abbreviated).day().year())")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this verse in the Bible")
        } else {
            Label(
                "Long-press any verse when reading the Bible to favorite or highlight that verse.",
                systemImage: "heart"
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
