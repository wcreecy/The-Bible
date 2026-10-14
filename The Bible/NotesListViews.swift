import SwiftData
import SwiftUI

struct NotesCategoryStrip: View {
    @Binding var selection: NotesFilter
    @Binding var highlightFilter: NotesHighlightFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if highlightFilter != .all {
                    activeHighlightChip
                }

                ForEach(NotesFilter.allCases) { filter in
                    Button {
                        withAnimation(.snappy) {
                            selection = filter
                        }
                    } label: {
                        Label(filter.title, systemImage: filter.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .foregroundStyle(selection == filter ? Color.white : Color.primary)
                            .background(
                                selection == filter ? Color.accentColor : Color.primary.opacity(0.07),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    /// Makes an active highlight filter visible and removable with one tap.
    private var activeHighlightChip: some View {
        Button {
            withAnimation(.snappy) {
                highlightFilter = .all
            }
        } label: {
            HStack(spacing: 6) {
                if let color = highlightFilter.highlightColor?.color {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "circle.slash")
                }
                Text(highlightFilter.title)
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .foregroundStyle(.primary)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.accentColor.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Highlight filter")
        .accessibilityValue(Text(highlightFilter.title))
        .accessibilityHint("Removes the highlight color filter")
    }
}

struct NotesListCard: View {
    let notes: [NotesListItem]
    let selectedID: NotesListItem.ID?
    let filter: NotesFilter
    let hasAnyNotes: Bool
    let showsClearFiltersAction: Bool
    let clearFiltersAction: () -> Void
    /// When provided, an inline "New Note" button appears in the list header.
    let newNoteAction: (() -> Void)?
    let createFirstNoteAction: () -> Void
    let selectAction: (NotesListItem) -> Void
    let editAction: (NotesListItem) -> Void
    let deleteAction: (NotesListItem) -> Void

    var body: some View {
        List {
            summaryHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: AppDesignMetrics.cardPadding,
                        leading: AppDesignMetrics.cardPadding,
                        bottom: 4,
                        trailing: AppDesignMetrics.cardPadding
                    )
                )

            if notes.isEmpty {
                emptyState
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if favoriteNotes.isEmpty {
                rows(for: otherNotes)
            } else {
                groupHeader("Favorites", systemImage: "star.fill")
                rows(for: favoriteNotes)

                if !otherNotes.isEmpty {
                    groupHeader("Notes", systemImage: "note.text")
                    rows(for: otherNotes)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.vertical, 0, for: .scrollContent)
        .clipShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .heroCardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var favoriteNotes: [NotesListItem] {
        notes.filter(\.isFavorite)
    }

    private var otherNotes: [NotesListItem] {
        notes.filter { !$0.isFavorite }
    }

    private var summaryHeader: some View {
        HStack(spacing: 8) {
            Text(filter.libraryTitle(noteCount: notes.count))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            if showsClearFiltersAction {
                // Icon-only when sharing the header with the New Note button.
                if newNoteAction == nil {
                    clearFiltersButton.labelStyle(.titleAndIcon)
                } else {
                    clearFiltersButton.labelStyle(.iconOnly)
                }
            }

            if let newNoteAction {
                Button("New Note", systemImage: "plus", action: newNoteAction)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clearFiltersButton: some View {
        Button("Clear All Filters", systemImage: "line.3.horizontal.decrease.circle") {
            clearFiltersAction()
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Clear all filters")
    }

    private func groupHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: 12,
                    leading: AppDesignMetrics.cardPadding,
                    bottom: 4,
                    trailing: AppDesignMetrics.cardPadding
                )
            )
    }

    @ViewBuilder
    private var emptyState: some View {
        if hasAnyNotes {
            ContentUnavailableView {
                Label("No Matching Notes", systemImage: "note.text")
            } description: {
                Text("Try another tag, color, or search.")
            } actions: {
                if showsClearFiltersAction {
                    Button("Clear All Filters", systemImage: "line.3.horizontal.decrease.circle") {
                        clearFiltersAction()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else {
            ContentUnavailableView {
                Label("No Notes Yet", systemImage: "note.text")
            } description: {
                Text("Tap + to write a note, or press and hold a verse in the Bible to add a note or highlight.")
            } actions: {
                Button("New Note", systemImage: "plus", action: createFirstNoteAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func rows(for items: [NotesListItem]) -> some View {
        ForEach(items) { item in
            NotesListRow(
                item: item,
                isSelected: item.id == selectedID,
                selectAction: { selectAction(item) },
                editAction: { editAction(item) },
                deleteAction: { deleteAction(item) }
            )
            .listRowBackground(
                item.id == selectedID ? Color.accentColor.opacity(0.13) : Color.clear
            )
            .listRowSeparator(item.id == items.last?.id ? .hidden : .visible)
            .listRowSeparatorTint(Color.primary.opacity(0.09))
            .listRowInsets(EdgeInsets())
        }
    }
}

/// A note row with the same quick actions everywhere: swipe on iPhone and iPad,
/// plus a press-and-hold (or right-click) menu.
struct NotesListRow: View {
    @Environment(\.modelContext) private var modelContext

    let item: NotesListItem
    let isSelected: Bool
    let selectAction: () -> Void
    let editAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        NotesTitleButton(
            title: item.title,
            preview: item.preview,
            reference: item.reference,
            tag: NoteCategory(rawValue: item.categoryRawValue)?.title,
            highlight: VerseHighlightColor(rawValue: item.highlightColor),
            isFavorite: item.isFavorite,
            updatedAt: item.updatedAt ?? item.createdAt,
            isSelected: isSelected,
            action: selectAction
        )
        .swipeActions(edge: .leading) {
            favoriteButton
                .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            deleteButton
        }
        .contextMenu {
            favoriteButton

            Button("Edit", systemImage: "pencil", action: editAction)

            ShareLink(item: item.shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            if item.reference != nil {
                Button("Open in Bible", systemImage: "book.closed") {
                    item.openInBible()
                }
            }

            Divider()

            deleteButton
        }
    }

    private var favoriteButton: some View {
        Button {
            item.toggleFavorite()
            modelContext.saveLoggingErrors()
            Haptics.selection()
        } label: {
            Label(
                item.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: item.isFavorite ? "star.slash" : "star"
            )
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: deleteAction) {
            Label {
                Text(item.deleteTitle)
            } icon: {
                Image(systemName: "trash")
            }
        }
    }
}

/// Combines sorting and the highlight color filter into a single toolbar menu.
struct NotesViewOptionsMenu: View {
    @Binding var sortField: NotesTabSort
    @Binding var sortAscending: Bool
    @Binding var highlightFilter: NotesHighlightFilter

    var body: some View {
        Menu {
            Section("Sort By") {
                Picker("Sort By", selection: $sortField) {
                    ForEach(NotesTabSort.allCases) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Picker("Order", selection: $sortAscending) {
                    Text(sortField.orderTitle(ascending: false)).tag(false)
                    Text(sortField.orderTitle(ascending: true)).tag(true)
                }
                .pickerStyle(.inline)
            }

            Section("Filter") {
                Picker(selection: $highlightFilter) {
                    ForEach(NotesHighlightFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    Label("Highlight Color", systemImage: "highlighter")
                    Text(highlightFilter.title)
                }
                .pickerStyle(.menu)
            }
        } label: {
            Image(
                systemName: highlightFilter == .all
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
            .foregroundStyle(
                highlightFilter == .all
                    ? AnyShapeStyle(.primary)
                    : AnyShapeStyle(.tint)
            )
        }
        .accessibilityLabel("Sort and filter notes")
        .accessibilityValue(Text(sortField.title))
    }
}

struct NotesTitleButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let preview: String
    let reference: String?
    let tag: LocalizedStringResource?
    let highlight: VerseHighlightColor?
    let isFavorite: Bool
    let updatedAt: Date?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                if let highlight {
                    Capsule()
                        .fill(highlight.color)
                        .frame(width: 3)
                        .padding(.vertical, 5)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 4)

                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Favorite")
                        }
                    }

                    if !preview.isEmpty {
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(horizontalSizeClass == .compact ? 2 : 1)
                    }

                    HStack(spacing: 6) {
                        if let tag {
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tint)
                        }
                        if let reference {
                            Label(reference, systemImage: "book.closed")
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let updatedAt {
                            Text(updatedAt, format: rowDateFormat(for: updatedAt))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                .padding(.leading, 12)
            }
            .frame(minHeight: 76, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Omits the year for this year's notes so older notes aren't mistaken for recent ones.
    private func rowDateFormat(for date: Date) -> Date.FormatStyle {
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return Calendar.current.isDate(date, equalTo: .now, toGranularity: .year) ? style : style.year()
    }
}
