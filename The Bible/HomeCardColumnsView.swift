import SwiftUI

/// The iPad Home dashboard's two card columns.
///
/// In Edit Home mode, cards stop responding to taps and show controls to hide them, move them
/// up or down, or move them to the other column; hidden cards appear as compact tiles so they
/// can be shown again.
///
/// System drag-to-reorder (`reorderable(collectionID:)`) isn't used: on iOS 27.0 it crashed
/// at lift ("Unexpected identifier type") once items had real card content.
struct HomeCardColumnsView<Card: View>: View {
    let columns: HomeColumnLayout
    let hiddenCards: Set<HomeCardID>
    let isEditing: Bool
    /// The width of both columns together; each column gets exactly half so wide card
    /// content can't push the columns past the page margins.
    let width: CGFloat
    let spacing: CGFloat
    let onMoveToOtherColumn: (HomeCardID) -> Void
    let onMoveWithinColumn: (_ id: HomeCardID, _ offset: Int) -> Void
    let onToggleHidden: (HomeCardID) -> Void
    @ViewBuilder let card: (HomeCardID) -> Card

    private var columnWidth: CGFloat {
        max(0, (width - spacing) / 2)
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            columnStack(.left)
                .frame(width: columnWidth)
            columnStack(.right)
                .frame(width: columnWidth)
        }
        .frame(width: width, alignment: .top)
    }

    /// Hidden cards are listed only while editing.
    private func cards(in column: HomeColumn) -> [HomeCardID] {
        isEditing ? columns[column] : columns[column].filter { !hiddenCards.contains($0) }
    }

    private func columnStack(_ column: HomeColumn) -> some View {
        let ids = cards(in: column)
        return VStack(spacing: spacing) {
            ForEach(ids, id: \.self) { id in
                item(for: id, in: column)
            }

            if isEditing && ids.isEmpty {
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

/// Edit Home controls: a bar above the card (which is padded down to make room) and a
/// dashed outline around both. The fill blocks the card's own buttons while editing.
struct HomeCardEditChrome: View {
    static let barHeight: CGFloat = 48

    let id: HomeCardID
    let column: HomeColumn
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onHide: () -> Void
    let onMoveToOtherColumn: () -> Void
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

            controlButton("chevron.up", label: "Move \(id.title) up", disabled: !canMoveUp) {
                onMoveWithinColumn(-1)
            }
            controlButton("chevron.down", label: "Move \(id.title) down", disabled: !canMoveDown) {
                onMoveWithinColumn(1)
            }
            controlButton(
                column.other == .right ? "arrow.right" : "arrow.left",
                label: "Move \(id.title) to the \(column.other.title.lowercased())",
                action: onMoveToOtherColumn
            )
        }
        .padding(.horizontal, 6)
        .frame(height: Self.barHeight)
    }

    private func controlButton(_ systemImage: String, label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
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

