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
    let systemImage: String
    let tint: Color

    func body(content: Content) -> some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: tint.opacity(0.24), radius: 12, y: 7)

            content
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .padding(.top, 8)
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

struct GameStartInfoLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsHelp = false

    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        Button {
            showsHelp = true
        } label: {
            Label("How to Play", systemImage: "questionmark.circle")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showsHelp) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing) {
                        content
                    }
                    .disclosureGroupStyle(ExpandedGameHelpDisclosureStyle())
                    .padding()
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }
                .navigationTitle("How to Play")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsHelp = false }
                    }
                }
            }
            .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
        }
        .accessibilityHint("Opens game instructions and difficulty details")
    }
}

private struct ExpandedGameHelpDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline)

            configuration.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GameStartCurrentGameCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        EmptyView()
    }
}

struct GameStartActionBar: View {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey = "Start Game",
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .controlSize(.large)
        .disabled(!isEnabled)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsSettings = false

    @ViewBuilder let content: Content

    var body: some View {
        Button {
            showsSettings = true
        } label: {
            Label("Game Settings", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        content
                    }
                    .padding()
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .navigationTitle("Game Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsSettings = false }
                    }
                }
            }
            .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
        }
        .accessibilityHint("Opens settings for this game")
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

struct GameStartMultiPickerCard<Value: Hashable, OptionLabel: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Set<Value>
    let options: [Value]
    @ViewBuilder let label: (Value) -> OptionLabel

    @State private var isExpanded = false

    var body: some View {
        GroupBox(title) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selection.contains(option)
                        Button {
                            if isSelected {
                                guard selection.count > 1 else { return }
                                selection.remove(option)
                            } else {
                                selection.insert(option)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                label(option)
                                    .font(.body.weight(isSelected ? .semibold : .regular))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .top)
            } label: {
                Label {
                    Text(selection.count == options.count ? "All" : "\(selection.count) selected")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
                .font(.body.weight(.semibold))
            }
        }
    }
}

extension View {
    func gameStartScreenStyle() -> some View {
        modifier(GameStartScreenStyle())
    }

    func gameStartDescriptionStyle(
        systemImage: String = "gamecontroller.fill",
        tint: Color = .accentColor
    ) -> some View {
        modifier(GameStartDescriptionStyle(systemImage: systemImage, tint: tint))
    }

    func gameStartOptionsStyle() -> some View {
        modifier(GameStartOptionsStyle())
    }

    func gameStartSettingsStyle() -> some View {
        modifier(GameStartSettingsStyle())
    }
}
