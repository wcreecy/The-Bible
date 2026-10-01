import SwiftUI

struct GameStartScreenStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? 980 : 620)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 24)
    }
}

struct GameStartDescriptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 520)
    }
}

struct GameStartOptionsStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .padding(horizontalSizeClass == .regular ? 0 : 16)
            .background(
                horizontalSizeClass == .regular ? AnyShapeStyle(.clear) : AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                if horizontalSizeClass != .regular {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }
            }
    }
}

struct GameStartInfoLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 16) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let availableWidth = proposal.width ?? 620

        if availableWidth >= 700 {
            let itemWidth = (availableWidth - spacing * CGFloat(subviews.count - 1)) / CGFloat(subviews.count)
            let sizes = subviews.map { $0.sizeThatFits(.init(width: itemWidth, height: proposal.height)) }
            return CGSize(width: availableWidth, height: sizes.map(\.height).max() ?? 0)
        }

        let sizes = subviews.map { $0.sizeThatFits(.init(width: availableWidth, height: nil)) }
        return CGSize(
            width: availableWidth,
            height: sizes.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1))
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        if bounds.width >= 700 {
            let itemWidth = (bounds.width - spacing * CGFloat(subviews.count - 1)) / CGFloat(subviews.count)
            for (index, subview) in subviews.enumerated() {
                subview.place(
                    at: CGPoint(x: bounds.minX + CGFloat(index) * (itemWidth + spacing), y: bounds.minY),
                    anchor: .topLeading,
                    proposal: .init(width: itemWidth, height: bounds.height)
                )
            }
        } else {
            var y = bounds.minY
            for subview in subviews {
                let size = subview.sizeThatFits(.init(width: bounds.width, height: nil))
                subview.place(
                    at: CGPoint(x: bounds.minX, y: y),
                    anchor: .topLeading,
                    proposal: .init(width: bounds.width, height: size.height)
                )
                y += size.height + spacing
            }
        }
    }
}

struct GameStartCurrentGameCard<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isExpanded = true

    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Current Game")
                    .font(.headline)
            }
        }
        .onAppear(perform: expandIfNeeded)
        .onChange(of: horizontalSizeClass) { _, _ in
            expandIfNeeded()
        }
    }

    private func expandIfNeeded() {
        guard horizontalSizeClass == .regular else { return }
        isExpanded = true
    }
}

struct GameStartCurrentGameRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct GameStartSettingsStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            GroupBox("Game Settings") {
                content
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
            }
        } else {
            content
        }
    }
}

struct GameStartSettingsLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GameStartInfoLayout(spacing: 16) {
            content
        }
    }
}

struct GameStartSettingCard<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        if horizontalSizeClass == .regular {
            GroupBox(title) {
                content
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            content
        }
    }
}

struct GameStartPickerCard<Value: Hashable, Label: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: LocalizedStringKey
    @Binding var selection: Value
    let options: [Value]
    @ViewBuilder let label: (Value) -> Label

    var body: some View {
        if horizontalSizeClass == .regular {
            GroupBox(title) {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = option
                        } label: {
                            HStack(spacing: 12) {
                                label(option)
                                    .font(.body.weight(selection == option ? .semibold : .regular))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: selection == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection == option ? Color.accentColor : Color.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(
                                selection == option ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == option ? .isSelected : [])
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    label(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
}

struct ExpandGameStartCardsOnIPad: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var howToExpanded: Bool
    @Binding var difficultyExpanded: Bool

    func body(content: Content) -> some View {
        content
            .onAppear(perform: expandCardsIfNeeded)
            .onChange(of: horizontalSizeClass) { _, _ in
                expandCardsIfNeeded()
            }
    }

    private func expandCardsIfNeeded() {
        guard horizontalSizeClass == .regular else { return }
        howToExpanded = true
        difficultyExpanded = true
    }
}

extension View {
    func gameStartScreenStyle() -> some View {
        modifier(GameStartScreenStyle())
    }

    func gameStartDescriptionStyle() -> some View {
        modifier(GameStartDescriptionStyle())
    }

    func gameStartOptionsStyle() -> some View {
        modifier(GameStartOptionsStyle())
    }

    func gameStartSettingsStyle() -> some View {
        modifier(GameStartSettingsStyle())
    }

    func expandGameStartCardsOnIPad(
        howTo howToExpanded: Binding<Bool>,
        difficulty difficultyExpanded: Binding<Bool>
    ) -> some View {
        modifier(
            ExpandGameStartCardsOnIPad(
                howToExpanded: howToExpanded,
                difficultyExpanded: difficultyExpanded
            )
        )
    }
}
