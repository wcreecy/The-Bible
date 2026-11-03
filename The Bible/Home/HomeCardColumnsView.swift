import SwiftUI

/// The iPad Home dashboard's three equal columns. The Today's Reading panel, when shown,
/// sits above the cards in its column. A wide Verse of the Day sits above the columns it
/// covers (see `HomeCardWidth`).
///
/// In Edit Home mode, cards stop responding to taps and show controls to hide them or move
/// them up, down, left, or right; hidden cards appear as compact tiles so they can be shown
/// again.
///
/// System drag-to-reorder (`reorderable(collectionID:)`) isn't used: on iOS 27.0 it crashed
/// at lift ("Unexpected identifier type") once items had real card content.
struct HomeCardColumnsView<Card: View, Reader: View>: View {
    let columns: HomeColumnLayout
    let hiddenCards: Set<HomeCardID>
    /// The Today's Reading panel's column, or nil when it's hidden.
    let readerColumn: HomeColumn?
    let isEditing: Bool
    /// The width of all three columns together; each gets exactly a third so wide card
    /// content can't push the columns past the page margins.
    let width: CGFloat
    let columnSpacing: CGFloat
    let cardSpacing: CGFloat
    let onMoveAcross: (_ id: HomeCardID, _ offset: Int) -> Void
    let onMoveWithinColumn: (_ id: HomeCardID, _ offset: Int) -> Void
    let onToggleHidden: (HomeCardID) -> Void
    /// Sets how many columns Verse of the Day covers: 1, 2, or 3.
    let onSetVerseOfDayColumnCount: (Int) -> Void
    @ViewBuilder let card: (HomeCardID) -> Card
    @ViewBuilder let reader: () -> Reader

    private var columnWidth: CGFloat {
        let count = CGFloat(HomeColumn.allCases.count)
        return max(0, (width - columnSpacing * (count - 1)) / count)
    }

    /// The width shown: a hidden Verse of the Day leaves no banner, except while editing,
    /// where its tile holds the banner's place.
    private var verseOfDayWidth: HomeCardWidth {
        isEditing || !hiddenCards.contains(.verseOfDay) ? columns.verseOfDayWidth : .oneColumn
    }

    var body: some View {
        let covered = verseOfDayWidth.coveredColumns
        HStack(alignment: .top, spacing: columnSpacing) {
            if covered.isEmpty {
                columnStacks(HomeColumn.allCases)
            } else {
                // Uncovered columns run the full height beside the banner and the columns
                // below it.
                columnStacks(Array(HomeColumn.allCases.prefix { $0 != covered[0] }))
                VStack(spacing: cardSpacing) {
                    item(for: .verseOfDay, in: nil)
                    HStack(alignment: .top, spacing: columnSpacing) {
                        columnStacks(covered)
                    }
                }
                .frame(width: spanWidth(covered.count))
                columnStacks(Array(HomeColumn.allCases.drop { $0 != covered[covered.count - 1] }.dropFirst()))
            }
        }
        .frame(width: width, alignment: .top)
    }

    private func spanWidth(_ count: Int) -> CGFloat {
        columnWidth * CGFloat(count) + columnSpacing * CGFloat(max(0, count - 1))
    }

    private func columnStacks(_ list: [HomeColumn]) -> some View {
        ForEach(list, id: \.self) { column in
            columnStack(column)
                .frame(width: columnWidth)
        }
    }

    /// Hidden cards are listed only while editing.
    private func cards(in column: HomeColumn) -> [HomeCardID] {
        let cards = columns.stackedCards(in: column)
        return isEditing ? cards : cards.filter { !hiddenCards.contains($0) }
    }

    private func columnStack(_ column: HomeColumn) -> some View {
        let ids = cards(in: column)
        return VStack(spacing: cardSpacing) {
            if readerColumn == column {
                reader()
            }

            ForEach(ids, id: \.self) { id in
                item(for: id, in: column)
            }

            if isEditing && ids.isEmpty && readerColumn != column {
                emptyColumnPlaceholder
            }
        }
    }

    /// `column` is nil for a card spanning above the columns.
    @ViewBuilder
    private func item(for id: HomeCardID, in column: HomeColumn?) -> some View {
        let isHidden = hiddenCards.contains(id)
        Group {
            if isEditing && isHidden {
                HiddenHomeCardTile(id: id) { onToggleHidden(id) }
            } else {
                // The same view in and out of editing, so cards keep their state. While
                // editing, the card moves down to make room for the edit bar above it, and its
                // own controls are set aside for VoiceOver in favor of the edit controls.
                card(id)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(!isEditing)
                    .accessibilityHidden(isEditing)
                    .padding(.top, isEditing ? HomeCardEditChrome.barHeight : 0)
                    .overlay {
                        if isEditing {
                            HomeCardEditChrome(
                                id: id,
                                canMoveUp: columns.canMove(id, by: -1),
                                canMoveDown: columns.canMove(id, by: 1),
                                canMoveLeft: columns.canMoveAcross(id, by: -1),
                                canMoveRight: columns.canMoveAcross(id, by: 1),
                                width: id == .verseOfDay ? columns.verseOfDayWidth : nil,
                                onSetColumnCount: onSetVerseOfDayColumnCount,
                                onHide: { onToggleHidden(id) },
                                onMoveAcross: { onMoveAcross(id, $0) },
                                onMoveWithinColumn: { onMoveWithinColumn(id, $0) }
                            )
                        }
                    }
            }
        }
        .accessibilityActions {
            if isEditing {
                if columns.canMove(id, by: -1) {
                    Button("Move up") { onMoveWithinColumn(id, -1) }
                }
                if columns.canMove(id, by: 1) {
                    Button("Move down") { onMoveWithinColumn(id, 1) }
                }
                if let left = column?.neighbor(by: -1) {
                    Button("Move to \(left.title)") { onMoveAcross(id, -1) }
                } else if column == nil, columns.canMoveAcross(id, by: -1) {
                    Button("Move left") { onMoveAcross(id, -1) }
                }
                if let right = column?.neighbor(by: 1) {
                    Button("Move to \(right.title)") { onMoveAcross(id, 1) }
                } else if column == nil, columns.canMoveAcross(id, by: 1) {
                    Button("Move right") { onMoveAcross(id, 1) }
                }
                if id == .verseOfDay {
                    ForEach(HomeCardWidthOption.allCases) { option in
                        if option.columnCount != columns.verseOfDayWidth.columnCount {
                            Button("Make \(option.title)") { onSetVerseOfDayColumnCount(option.columnCount) }
                        }
                    }
                }
                Button(isHidden ? "Show" : "Hide") { onToggleHidden(id) }
            }
        }
    }

    private var emptyColumnPlaceholder: some View {
        Text("Use the arrows on a card to move it here.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
            .overlay {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
    }
}

/// Edit Home controls: a bar above the card (which is padded down to make room) and a
/// dashed outline around both. The fill blocks the card's own buttons while editing.
struct HomeCardEditChrome: View {
    static let barHeight: CGFloat = 48

    let id: HomeCardID
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canMoveLeft: Bool
    let canMoveRight: Bool
    /// The card's width, for cards whose width can change; shows a width menu.
    var width: HomeCardWidth?
    var onSetColumnCount: (Int) -> Void = { _ in }
    let onHide: () -> Void
    /// Moves the card to the neighboring column: -1 is left, +1 is right.
    let onMoveAcross: (Int) -> Void
    let onMoveWithinColumn: (Int) -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(0.06))
            .strokeBorder(Color.accentColor.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
            .contentShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
            .accessibilityHidden(true)
            .overlay(alignment: .top) {
                bar
            }
    }

    private var bar: some View {
        HStack(spacing: 6) {
            Button(action: onHide) {
                Image(systemName: "minus.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide \(id.title)")

            Spacer(minLength: 0)

            if let width {
                widthMenu(width)
            }

            HomeEditControlButton(systemImage: "arrow.left", label: "Move \(id.title) left", disabled: !canMoveLeft) {
                onMoveAcross(-1)
            }
            HomeEditControlButton(systemImage: "chevron.up", label: "Move \(id.title) up", disabled: !canMoveUp) {
                onMoveWithinColumn(-1)
            }
            HomeEditControlButton(systemImage: "chevron.down", label: "Move \(id.title) down", disabled: !canMoveDown) {
                onMoveWithinColumn(1)
            }
            HomeEditControlButton(systemImage: "arrow.right", label: "Move \(id.title) right", disabled: !canMoveRight) {
                onMoveAcross(1)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: Self.barHeight)
    }

    private func widthMenu(_ width: HomeCardWidth) -> some View {
        Menu {
            Picker("Width", selection: Binding(get: { width.columnCount }, set: onSetColumnCount)) {
                ForEach(HomeCardWidthOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option.columnCount)
                }
            }
        } label: {
            Image(systemName: "arrow.left.and.right")
                .font(.subheadline.weight(.semibold))
                .frame(width: 36, height: 36)
                .contentShape(.circle)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("\(id.title) width")
        .accessibilityValue(HomeCardWidthOption(columnCount: width.columnCount).title)
    }
}

/// The widths offered for Verse of the Day. Which two columns a two-column card covers is
/// chosen with the left and right arrows.
enum HomeCardWidthOption: Int, CaseIterable, Identifiable {
    case one = 1, two, full

    init(columnCount: Int) {
        self = HomeCardWidthOption(rawValue: min(3, max(1, columnCount))) ?? .one
    }

    var id: Int { rawValue }
    var columnCount: Int { rawValue }

    var title: String {
        switch self {
        case .one: return "One Column"
        case .two: return "Two Columns"
        case .full: return "Full Width"
        }
    }

    /// The short name used in segmented pickers.
    var shortTitle: String {
        switch self {
        case .one: return "One"
        case .two: return "Two"
        case .full: return "Full"
        }
    }

    var systemImage: String {
        switch self {
        case .one: return "rectangle.portrait"
        case .two: return "rectangle.split.2x1"
        case .full: return "rectangle"
        }
    }
}

/// A round glass button used in Edit Home bars.
struct HomeEditControlButton: View {
    let systemImage: String
    let label: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 36, height: 36)
                .contentShape(.circle)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

/// A hidden card's stand-in while editing, so it can be placed and shown again.
private struct HiddenHomeCardTile: View {
    let id: HomeCardID
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: id.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(id.title)
                    .font(.headline)
                Text("Hidden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onShow) {
                Label("Show", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Show \(id.title)")
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                .strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
        .contentShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }
}
