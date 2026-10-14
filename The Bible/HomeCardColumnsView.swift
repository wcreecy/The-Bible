import SwiftUI

/// The iPad Home dashboard's three equal columns. The Today's Reading panel, when shown,
/// sits above the cards in its column.
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
    @ViewBuilder let card: (HomeCardID) -> Card
    @ViewBuilder let reader: () -> Reader

    private var columnWidth: CGFloat {
        let count = CGFloat(HomeColumn.allCases.count)
        return max(0, (width - columnSpacing * (count - 1)) / count)
    }

    var body: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            ForEach(HomeColumn.allCases, id: \.self) { column in
                columnStack(column)
                    .frame(width: columnWidth)
            }
        }
        .frame(width: width, alignment: .top)
    }

    /// Hidden cards are listed only while editing.
    private func cards(in column: HomeColumn) -> [HomeCardID] {
        isEditing ? columns[column] : columns[column].filter { !hiddenCards.contains($0) }
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

    @ViewBuilder
    private func item(for id: HomeCardID, in column: HomeColumn) -> some View {
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
                if let left = column.neighbor(by: -1) {
                    Button("Move to \(left.title)") { onMoveAcross(id, -1) }
                }
                if let right = column.neighbor(by: 1) {
                    Button("Move to \(right.title)") { onMoveAcross(id, 1) }
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
