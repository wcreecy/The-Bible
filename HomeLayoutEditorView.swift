import SwiftUI

struct HomeLayoutEditorView: View {
    @Binding var order: [HomeCardID]
    @Binding var hiddenSet: Set<HomeCardID>
    var onDone: () -> Void

    var onSaveFavorite: () -> Void
    var onResetToFavorite: () -> Void
    var hasFavorite: Bool

    @State private var editMode: EditMode = .active

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
        onDone()
    }

    private func showAll() {
        hiddenSet.removeAll()
        onDone()
    }

    @ViewBuilder
    private func footerButton(title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(.accentColor)
        .controlSize(.large)
        .font(.subheadline)
        .disabled(disabled)
    }

    var body: some View {
        List {
            Section {
                ForEach(order) { id in
                    HStack {
                        Image(systemName: id.systemImage)
                            .foregroundStyle(.secondary)
                        Text(id.title)
                        Spacer()
                        Button {
                            toggleVisibility(id)
                        } label: {
                            Image(systemName: isVisible(id) ? "eye" : "eye.slash")
                                .foregroundStyle(isVisible(id) ? .blue : .secondary)
                                .accessibilityLabel(isVisible(id) ? "Hide" : "Show")
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Toggles visibility on the Home page")
                    }
                }
                .onMove { indices, newOffset in
                    order.move(fromOffsets: indices, toOffset: newOffset)
                    onDone()
                }
            } header: {
                Text("Order & Visibility")
            } footer: {
                VStack(alignment: .leading, spacing: 10) {
                    footerButton(title: "Reset Order", systemImage: "arrow.counterclockwise") {
                        resetToDefault()
                    }
                    footerButton(title: "Show All Cards", systemImage: "eye") {
                        showAll()
                    }
                    footerButton(title: "Apply Favorite", systemImage: "star", disabled: !hasFavorite) {
                        onResetToFavorite()
                    }

                    Text("Drag to reorder. Tap the eye to show or hide a card on the Home page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .environment(\.editMode, $editMode)
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
