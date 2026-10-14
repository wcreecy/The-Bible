import SwiftUI

/// The iPad Home dashboard's two card columns.
///
/// In Edit Home mode, cards stop responding to taps and show controls to hide them or move
/// them to the other column; hidden cards appear as compact tiles so they can be shown again.
/// On iOS 27 and later, cards can also be dragged within and between columns.
struct HomeCardColumnsView<Card: View>: View {
    let columns: HomeColumnLayout
    let hiddenCards: Set<HomeCardID>
    let isEditing: Bool
    let spacing: CGFloat
    /// Moves cards into a column before a card, or to the end when that card is nil.
    let onReorder: (_ ids: [HomeCardID], _ column: HomeColumn, _ before: HomeCardID?) -> Void
    let onMoveToOtherColumn: (HomeCardID) -> Void
    let onMoveWithinColumn: (_ id: HomeCardID, _ offset: Int) -> Void
    let onToggleHidden: (HomeCardID) -> Void
    @ViewBuilder let card: (HomeCardID) -> Card

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            columnStack(.left)
            columnStack(.right)
        }
        .modifier(HomeCardReorderContainer(isEnabled: isEditing, onReorder: onReorder))
    }

    /// Hidden cards are listed only while editing.
    private func cards(in column: HomeColumn) -> [HomeCardID] {
        isEditing ? columns[column] : columns[column].filter { !hiddenCards.contains($0) }
    }

    private func columnStack(_ column: HomeColumn) -> some View {
        let ids = cards(in: column)
        return VStack(spacing: spacing) {
            if #available(iOS 27.0, *) {
                ForEach(ids) { id in
                    item(for: id, in: column)
                }
                .reorderable(collectionID: column)
            } else {
                ForEach(ids) { id in
                    item(for: id, in: column)
                }
            }

            if isEditing && ids.isEmpty {
                emptyColumnPlaceholder
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func item(for id: HomeCardID, in column: HomeColumn) -> some View {
        let isHidden = hiddenCards.contains(id)
        Group {
            if isEditing && isHidden {
                HiddenHomeCardTile(id: id) { onToggleHidden(id) }
            } else {
                // The same view in and out of editing, so cards keep their state.
                card(id)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(!isEditing)
                    .overlay {
                        if isEditing {
                            HomeCardEditChrome(
                                id: id,
                                column: column,
                                canMoveUp: columns.canMove(id, by: -1),
                                canMoveDown: columns.canMove(id, by: 1),
                                onHide: { onToggleHidden(id) },
                                onMoveToOtherColumn: { onMoveToOtherColumn(id) },
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
                Button("Move to \(column.other.title)") { onMoveToOtherColumn(id) }
                Button(isHidden ? "Show" : "Hide") { onToggleHidden(id) }
            }
        }
    }

    private var emptyColumnPlaceholder: some View {
        Text("Use the arrow on a card to move it here.")
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

/// Enables system drag-to-reorder across both columns on iOS 27 and later.
private struct HomeCardReorderContainer: ViewModifier {
    let isEnabled: Bool
    let onReorder: (_ ids: [HomeCardID], _ column: HomeColumn, _ before: HomeCardID?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.reorderContainer(for: HomeCardID.self, in: HomeColumn.self, isEnabled: isEnabled) { difference in
                let ids = difference.sources.compactMap(HomeCardID.init(rawValue:))
                let before: HomeCardID?
                switch difference.destination.position {
                case .before(let id):
                    before = HomeCardID(rawValue: id)
                case .end:
                    before = nil
                }
                onReorder(ids, difference.destination.collectionID, before)
            }
        } else {
            content
        }
    }
}

/// Controls drawn over a card in Edit Home mode. The clear fill also blocks the card's own
/// buttons, so a press starts a drag instead of an action.
private struct HomeCardEditChrome: View {
    let id: HomeCardID
    let column: HomeColumn
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onHide: () -> Void
    let onMoveToOtherColumn: () -> Void
    let onMoveWithinColumn: (Int) -> Void

    /// Without system drag, up and down buttons are the way to reorder within a column.
    private var showsVerticalMoves: Bool {
        if #available(iOS 27.0, *) { return false }
        return true
    }

    var body: some View {
        RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(0.06))
            .strokeBorder(Color.accentColor.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
            .contentShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
            .overlay(alignment: .topLeading) {
                Button(action: onHide) {
                    Image(systemName: "minus.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("Hide \(id.title)")
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 4) {
                    if showsVerticalMoves {
                        controlButton("chevron.up", label: "Move \(id.title) up", disabled: !canMoveUp) {
                            onMoveWithinColumn(-1)
                        }
                        controlButton("chevron.down", label: "Move \(id.title) down", disabled: !canMoveDown) {
                            onMoveWithinColumn(1)
                        }
                    }
                    controlButton(
                        column.other == .right ? "arrow.right" : "arrow.left",
                        label: "Move \(id.title) to the \(column.other.title.lowercased())",
                        action: onMoveToOtherColumn
                    )
                }
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)
                .padding(8)
            }
            .accessibilityHidden(true)
    }

    private func controlButton(_ systemImage: String, label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, height: 32)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
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
