import SwiftData
import SwiftUI

/// The Notes page's filters in one row: type, highlight color, and custom tags. Tags open
/// a second row listing each tag with how many notes use it.
struct NotesFilterBar: View {
    @Binding var filters: NotesFilters

    let tags: [NotesLibrary.TagCount]
    let manageTagsAction: () -> Void

    @State private var isShowingTags = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(NotesFilter.allCases) { filter in
                        FilterChip(isSelected: filters.category == filter) {
                            update { $0.category = filter }
                        } label: {
                            Label { Text(filter.title) } icon: { Image(systemName: filter.systemImage) }
                        }
                    }

                    colorChip

                    if !tags.isEmpty || filters.tag != nil {
                        FilterChip(isSelected: isShowingTags || filters.tag != nil) {
                            withAnimation(.snappy) { isShowingTags.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(filters.tag.map { "#\($0)" } ?? String(localized: "#Tags"))
                                Image(systemName: isShowingTags ? "chevron.up" : "chevron.down")
                                    .font(.caption2.weight(.bold))
                            }
                        }
                        .accessibilityLabel("Custom tags")
                        .accessibilityValue(Text(filters.tag.map { "#\($0)" } ?? String(localized: "All")))
                        .accessibilityHint(isShowingTags ? "Hides your custom note tags" : "Shows your custom note tags")
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)

            if isShowingTags {
                tagRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    /// Picks a highlight color; shows the chosen color and clears with one tap from the menu.
    private var colorChip: some View {
        Menu {
            Picker("Highlight Color", selection: binding(\.highlight)) {
                ForEach(NotesHighlightFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterChipLabel(isSelected: filters.highlight != .all) {
                HStack(spacing: 6) {
                    if let color = filters.highlight.highlightColor?.color {
                        Circle().fill(color).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: filters.highlight == .none ? "circle.slash" : "highlighter")
                    }
                    Text(filters.highlight == .all ? "Color" : filters.highlight.title)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Highlight color")
        .accessibilityValue(Text(filters.highlight.title))
    }

    private var tagRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(isSelected: filters.tag == nil) {
                    update { $0.tag = nil }
                } label: {
                    Label("All Tags", systemImage: "tag")
                }

                ForEach(tags) { tag in
                    FilterChip(isSelected: filters.tag == tag.tag) {
                        update { $0.tag = $0.tag == tag.tag ? nil : tag.tag }
                    } label: {
                        HStack(spacing: 5) {
                            Text(verbatim: "#\(tag.tag)")
                            Text(tag.count, format: .number)
                                .font(.caption.weight(.semibold))
                                .opacity(0.65)
                        }
                    }
                    .accessibilityLabel(Text(verbatim: "#\(tag.tag)"))
                    .accessibilityValue(Text("\(tag.count) notes"))
                }

                Button("Manage", systemImage: "slider.horizontal.3", action: manageTagsAction)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .clipShape(Capsule())
                    .accessibilityLabel("Manage tags")
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Custom note tags")
    }

    private func update(_ change: (inout NotesFilters) -> Void) {
        withAnimation(.snappy) { change(&filters) }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<NotesFilters, Value>) -> Binding<Value> {
        Binding(
            get: { filters[keyPath: keyPath] },
            set: { newValue in withAnimation(.snappy) { filters[keyPath: keyPath] = newValue } }
        )
    }
}

/// A capsule-shaped toggle used across the Notes filter row.
struct FilterChip<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Content

    var body: some View {
        Button(action: action) {
            FilterChipLabel(isSelected: isSelected, content: label)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The chip's appearance, shared with menus that look like chips.
struct FilterChipLabel<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color.primary.opacity(0.07), in: Capsule())
            .contentShape(Capsule())
    }
}

struct NotesListCard: View {
    let notes: [NotesListItem]
    let selectedID: NotesListItem.ID?
    /// Names the active filters and the count, so the list always says what it's showing.
    let summaryTitle: String
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
            Text(summaryTitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

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
            reference: item.passage,
            tag: item.category?.shortTitle,
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

            if item.bibleLocation != nil {
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
            item.toggleFavorite(in: modelContext)
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

/// Sorting, what to show, tag management, and export in one toolbar menu.
struct NotesViewOptionsMenu: View {
    @Binding var sortField: NotesTabSort
    @Binding var sortAscending: Bool
    @Binding var contentFilter: NotesContentFilter
    let hasTags: Bool
    let manageTagsAction: () -> Void
    let exportAction: () -> Void

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

            Section {
                Picker(selection: $contentFilter) {
                    ForEach(NotesContentFilter.allCases) { option in
                        Label(option.title, systemImage: option.systemImage).tag(option)
                    }
                } label: {
                    Label("Show", systemImage: "eye")
                    Text(contentFilter.title)
                }
                .pickerStyle(.menu)
            }

            Section {
                if hasTags {
                    Button("Manage Tags…", systemImage: "tag", action: manageTagsAction)
                }
                Button("Export All Notes…", systemImage: "square.and.arrow.up", action: exportAction)
            }
        } label: {
            Image(
                systemName: contentFilter == .all
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
            .foregroundStyle(
                contentFilter == .all
                    ? AnyShapeStyle(.primary)
                    : AnyShapeStyle(.tint)
            )
        }
        .accessibilityLabel("Sort, show, and export notes")
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
