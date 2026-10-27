import SwiftData
import SwiftUI

/// The Notes page's filters in one row: smart metadata and custom tags. Tags open a
/// second row listing each tag with how many notes use it.
struct NotesFilterBar: View {
    @Binding var filters: NotesFilters

    let tags: [NotesLibrary.TagCount]
    let manageTagsAction: () -> Void
    let clearFiltersAction: (() -> Void)?

    @State private var isShowingTags = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(NotesFilter.allCases) { filter in
                        FilterChip(isSelected: filters.category == filter) {
                            update { $0.category = $0.category == filter ? .all : filter }
                        } label: {
                            Label { Text(filter.title) } icon: { Image(systemName: filter.systemImage) }
                        }
                    }

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

            if let clearFiltersAction {
                NotesActiveFiltersSummary(
                    category: filters.category,
                    tag: filters.tag,
                    search: filters.search,
                    clearAction: clearFiltersAction
                )
            }
        }
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
}

/// States exactly what is narrowing the list, with the reset action where it is needed.
struct NotesActiveFiltersSummary: View {
    let category: NotesFilter
    let tag: String?
    let search: String
    let clearAction: () -> Void

    private var activeDescription: String {
        var parts = [String]()
        if category != .all {
            parts.append(String(localized: category.title))
        }
        if let tag {
            parts.append("#\(tag)")
        }
        let trimmedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            parts.append("“\(trimmedSearch)”")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Showing: \(activeDescription)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button("Clear filters", systemImage: "xmark.circle", action: clearAction)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Clear all filters")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
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
    let sections: [NotesListSection]
    let selectedID: NotesListItem.ID?
    let hasAnyNotes: Bool
    let showsClearFiltersAction: Bool
    let clearFiltersAction: () -> Void
    let createFirstNoteAction: () -> Void
    let selectAction: (NotesListItem) -> Void
    let editAction: (NotesListItem) -> Void
    let deleteAction: (NotesListItem) -> Void

    /// Each heading sits above its own card, which is sized to its notes.
    var body: some View {
        List {
            if sections.isEmpty {
                Section {
                    emptyState
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                }
                .listRowSeparator(.hidden)
            }

            ForEach(sections) { section in
                Section {
                    rows(for: section.items)
                } header: {
                    if let title = section.title {
                        groupHeader(section, title: title)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .tabBarContentClearance()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The card surface behind each row, tinted for the open note. The first and last rows
    /// round the card's corners; the list doesn't round them itself without side margins,
    /// which are left out so cards line up with the page.
    private func rowBackground(isSelected: Bool, isFirst: Bool, isLast: Bool) -> some View {
        let radius = AppDesignMetrics.cardCornerRadius
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? radius : 0,
            bottomLeadingRadius: isLast ? radius : 0,
            bottomTrailingRadius: isLast ? radius : 0,
            topTrailingRadius: isFirst ? radius : 0,
            style: .continuous
        )
        return shape
            .fill(.regularMaterial)
            .overlay(isSelected ? Color.accentColor.opacity(0.15) : Color.clear, in: shape)
    }

    private func groupHeader(_ section: NotesListSection, title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let systemImage = section.systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(section.id == "favorites" ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(.tint))
                    .accessibilityHidden(true)
            }
            Text(verbatim: title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(section.items.count, format: .number)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(section.items.count) notes")
        }
        // Keeps the heading's own capitalization and lines it up with the card's edges.
        .textCase(nil)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var emptyState: some View {
        if hasAnyNotes {
            ContentUnavailableView {
                Label("No Matching Notes", systemImage: "note.text")
            } description: {
                Text("Try another type, tag, or search.")
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
                Text("Tap + to write a note, or press and hold a verse in the Bible to add a note to it.")
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
            .listRowBackground(rowBackground(
                isSelected: item.id == selectedID,
                isFirst: item.id == items.first?.id,
                isLast: item.id == items.last?.id
            ))
            // Lines only between notes; the rounded card already marks its top and bottom.
            .listRowSeparator(item.id == items.first?.id ? .hidden : .automatic, edges: .top)
            .listRowSeparator(item.id == items.last?.id ? .hidden : .automatic, edges: .bottom)
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
            reference: item.rowPassage,
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

/// Sorting, filtering, tag management, and export in one toolbar menu.
struct NotesViewOptionsMenu: View {
    @Binding var sortField: NotesTabSort
    @Binding var sortAscending: Bool

    @Binding var filters: NotesFilters

    let tags: [NotesLibrary.TagCount]
    let showsFilters: Bool
    let hasTags: Bool
    let manageTagsAction: () -> Void
    let clearFiltersAction: () -> Void
    let exportAction: () -> Void

    var body: some View {
        Menu {
            if showsFilters {
                Section("Filter Notes") {
                    Picker("Note Type", selection: $filters.category) {
                        ForEach(NotesFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage)
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.inline)

                    if !tags.isEmpty || filters.tag != nil {
                        Picker("Tag", selection: $filters.tag) {
                            Text("All Tags").tag(String?.none)

                            ForEach(tags) { tag in
                                Text(verbatim: "#\(tag.tag)")
                                    .tag(Optional(tag.tag))
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    if filters.isActive {
                        Button("Clear Filters", systemImage: "arrow.counterclockwise", action: clearFiltersAction)
                    }
                }
            }

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
                if hasTags {
                    Button("Manage Tags…", systemImage: "tag", action: manageTagsAction)
                }
                Button("Export All Notes…", systemImage: "square.and.arrow.up", action: exportAction)
            }
        } label: {
            Image(systemName: showsFilters && filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
        }
        .accessibilityLabel(showsFilters ? "Filter, sort, and export notes" : "Sort and export notes")
        .accessibilityValue(showsFilters && filters.isActive ? Text("Filters active") : Text(sortField.title))
    }
}

/// A written note's row: the title and date, a line of preview, then its passage.
struct NotesTitleButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let preview: String
    let reference: String?
    let isFavorite: Bool
    let updatedAt: Date?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(isSelected ? .semibold : .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 4)

                        if let updatedAt {
                            Text(updatedAt, format: NotesRowDate.format(for: updatedAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !preview.isEmpty {
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(horizontalSizeClass == .compact ? 2 : 1)
                    }

                    if let reference {
                        Text(reference)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 12)
            }
            .frame(minHeight: 60, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isFavorite ? Text("Favorite") : Text(""))
    }
}

enum NotesRowDate {
    /// Omits the year for this year's notes so older notes aren't mistaken for recent ones.
    static func format(for date: Date) -> Date.FormatStyle {
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return Calendar.current.isDate(date, equalTo: .now, toGranularity: .year) ? style : style.year()
    }
}
