import SwiftUI

struct HomeLayoutEditorView: View {
    @Binding var order: [HomeCardID]
    @Binding var hiddenSet: Set<HomeCardID>
    @Binding var mainSet: Set<HomeCardID>
    @Binding var showMoreVisible: Bool
    let allowsShowMore: Bool
    var onDone: () -> Void

    var onSaveFavorite: () -> Void
    var onResetToFavorite: () -> Void
    var hasFavorite: Bool

    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    private var mainCards: [HomeCardID] {
        order.filter { mainSet.contains($0) }
    }

    private var showMoreCards: [HomeCardID] {
        order.filter { !mainSet.contains($0) }
    }

    private func isVisible(_ id: HomeCardID) -> Bool {
        !hiddenSet.contains(id)
    }

    private func toggleVisibility(_ id: HomeCardID) {
        if hiddenSet.contains(id) {
            hiddenSet.remove(id)
        } else {
            hiddenSet.insert(id)
        }
        onDone()
    }

    private func resetToDefault() {
        order = HomeCardID.allCases
        hiddenSet = HomeLayoutStore.baselineHidden
        mainSet = HomeLayoutStore.baselineMain
        showMoreVisible = true
        onDone()
    }

    private func showAll() {
        hiddenSet.removeAll()
        onDone()
    }

    private func moveCard(_ id: HomeCardID, by offset: Int) {
        if !allowsShowMore {
            guard id != .verseOfDay else { return }
            var cards = [.verseOfDay] + order.filter { $0 != .verseOfDay }
            guard let index = cards.firstIndex(of: id) else { return }
            let destination = index + offset
            guard destination > 0, cards.indices.contains(destination) else { return }
            cards.swapAt(index, destination)
            order = cards
            onDone()
            return
        }

        var main = mainCards
        var more = showMoreCards
        if let index = main.firstIndex(of: id) {
            let destination = index + offset
            if main.indices.contains(destination) {
                main.swapAt(index, destination)
            } else if offset > 0 && index == main.index(before: main.endIndex) {
                main.remove(at: index)
                more.insert(id, at: more.startIndex)
                mainSet.remove(id)
            } else {
                return
            }
        } else if let index = more.firstIndex(of: id) {
            let destination = index + offset
            if more.indices.contains(destination) {
                more.swapAt(index, destination)
            } else if offset < 0 && index == more.startIndex {
                more.remove(at: index)
                main.append(id)
                mainSet.insert(id)
            } else {
                return
            }
        } else {
            return
        }
        order = main + more
        onDone()
    }

    private func canMoveUp(_ id: HomeCardID) -> Bool {
        if !allowsShowMore {
            let cards = [.verseOfDay] + order.filter { $0 != .verseOfDay }
            return id != .verseOfDay && cards.firstIndex(of: id).map { $0 > 1 } == true
        }
        if let index = mainCards.firstIndex(of: id) { return index > 0 }
        return showMoreCards.contains(id)
    }

    private func canMoveDown(_ id: HomeCardID) -> Bool {
        if !allowsShowMore {
            let cards = [.verseOfDay] + order.filter { $0 != .verseOfDay }
            return id != .verseOfDay && cards.firstIndex(of: id).map { $0 < cards.count - 1 } == true
        }
        if let index = mainCards.firstIndex(of: id) { return index < mainCards.count - 1 || allowsShowMore }
        return showMoreCards.firstIndex(of: id).map { $0 < showMoreCards.count - 1 } == true
    }

    private func layoutRow(for id: HomeCardID) -> some View {
        HStack {
            Image(systemName: id.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(id.title)

            Spacer()

            Button {
                toggleVisibility(id)
            } label: {
                Label(
                    isVisible(id) ? "Shown" : "Hidden",
                    systemImage: isVisible(id) ? "eye" : "eye.slash"
                )
                .font(.subheadline)
                .foregroundStyle(isVisible(id) ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(isVisible(id) ? "Hide" : "Show") \(id.title)")
            .accessibilityHint("Changes whether this card is available on Home")

            HStack(spacing: 4) {
                Button {
                    moveCard(id, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 28, height: 32)
                }
                .disabled(!canMoveUp(id))
                .accessibilityLabel("Move \(id.title) up")

                Button {
                    moveCard(id, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 28, height: 32)
                }
                .disabled(!canMoveDown(id))
                .accessibilityLabel("Move \(id.title) down")
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func footerButton(title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
        .controlSize(.large)
        .font(.subheadline)
        .disabled(disabled)
    }

    var body: some View {
        List {
            if contextualTipsEnabled {
                ContextualTipView(
                    title: "Make Home yours",
                    message: allowsShowMore
                        ? "Use the arrow buttons to reorder cards or move them between Main Home and Show More."
                        : "Use the eye buttons to show or hide cards, and the arrows to reorder them.",
                    systemImage: "rectangle.grid.1x2"
                )
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(allowsShowMore ? mainCards : [.verseOfDay] + order.filter { $0 != .verseOfDay }) { id in
                    layoutRow(for: id)
                }
            } header: {
                Label(allowsShowMore ? "Main Home" : "Home Cards", systemImage: "house")
            } footer: {
                Text(allowsShowMore
                    ? "Shown cards appear directly on Home. Use the arrows to arrange them."
                    : "Shown cards appear on Home. Use the arrows to choose their order.")
            }

            if allowsShowMore {
                Section {
                    Toggle(isOn: $showMoreVisible) {
                        Label("Show ‘Show More’ on Home", systemImage: showMoreVisible ? "eye" : "eye.slash")
                    }
                    .toggleStyle(StatusColorToggleStyle())
                    .onChange(of: showMoreVisible) { _, _ in
                        onDone()
                    }

                    ForEach(showMoreCards) { id in
                        layoutRow(for: id)
                    }
                } header: {
                    Label("Inside Show More", systemImage: "square.grid.2x2")
                } footer: {
                    Text(showMoreVisible
                        ? "Shown cards become visible only after Show More is expanded. Use the arrows to arrange them."
                        : "Show More is hidden from Home. You can still arrange its cards here for later.")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    footerButton(title: "Reset Layout", systemImage: "arrow.counterclockwise") {
                        resetToDefault()
                    }
                    footerButton(title: "Show All Cards", systemImage: "eye") {
                        showAll()
                    }
                    footerButton(title: "Apply Favorite", systemImage: "star", disabled: !hasFavorite) {
                        onResetToFavorite()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HomeBackgroundSection()
        }
        .navigationTitle("Home Layout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save as Favorite") {
                    onSaveFavorite()
                }
            }
        }
    }
}

private struct StatusColorToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack {
                configuration.label

                Spacer()

                Capsule()
                    .fill(configuration.isOn ? Color.green : Color.red)
                    .frame(width: 51, height: 31)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .padding(2)
                            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeBackgroundSection: View {
    var body: some View {
        Section {
            BackgroundEditor(tab: .home, showsApplyToAllPages: false)
        } header: {
            Label("Home Background", systemImage: "photo.on.rectangle")
        } footer: {
            Text("Choose the default background, a photo, or a custom color for Home.")
        }
    }
}
