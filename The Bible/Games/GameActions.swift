import SwiftUI

// Shared game actions, so every game gives up, shows its options, and answers Apple Pencil
// the same way.

// MARK: - Give Up

extension View {
    /// The confirmation every game shows before giving up. `title` names what's given up
    /// ("Give up this word?") and `message` says what happens next.
    func gameGiveUpConfirmation(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        message: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button("Give Up", role: .destructive, action: action)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

/// The ••• menu in a game's toolbar: the game's own options first, then Give Up last.
struct GameOptionsMenu<Content: View>: View {
    let gameTitle: LocalizedStringKey
    var canGiveUp = true
    let onGiveUp: () -> Void
    @ViewBuilder var content: Content

    init(
        gameTitle: LocalizedStringKey,
        canGiveUp: Bool = true,
        onGiveUp: @escaping () -> Void,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.gameTitle = gameTitle
        self.canGiveUp = canGiveUp
        self.onGiveUp = onGiveUp
        self.content = content()
    }

    var body: some View {
        Menu {
            content
            if canGiveUp {
                Divider()
                GameGiveUpButton(action: onGiveUp)
            }
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
        }
        .accessibilityLabel(Text("\(Text(gameTitle)) options"))
    }
}

/// Give Up, as it appears in the options menu and the Apple Pencil menu.
struct GameGiveUpButton: View {
    let action: () -> Void

    var body: some View {
        Button("Give Up", systemImage: "flag.fill", role: .destructive, action: action)
    }
}

// MARK: - Apple Pencil

/// How every game answers Apple Pencil:
/// - **Double-tap** takes the safe next step: Next (or See Results) once the round is over,
///   otherwise the game's Submit or Check. It never spends a hint.
/// - **Squeeze** opens the game's actions in a popover at the Pencil tip, in the same order
///   everywhere: Next, then hints, then Give Up. Squeezing right on an answer or tile still
///   picks it in games that support that.
///
/// Both follow the person's Pencil settings: a gesture set to "ignore" does nothing.
enum GamePencil {
    /// Views inside a game report points in this space when they open the Pencil menu.
    static let coordinateSpace = "gamePencil"
}

/// Opens the game's Pencil menu at a point in `GamePencil.coordinateSpace`. Views that handle
/// the squeeze themselves (to pick the answer under the Pencil) call this when nothing is there.
struct GamePencilMenuAction {
    fileprivate let present: (CGPoint?) -> Void

    func callAsFunction(at point: CGPoint? = nil) {
        present(point)
    }
}

extension EnvironmentValues {
    @Entry var showGamePencilMenu = GamePencilMenuAction(present: { _ in })
}

private struct GamePencilActionsModifier<MenuContent: View>: ViewModifier {
    @Environment(\.preferredPencilDoubleTapAction) private var doubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var squeezeAction
    @State private var isPresented = false
    @State private var anchor: PopoverAttachmentAnchor = .point(.center)
    @State private var size: CGSize = .zero

    let isEnabled: Bool
    let handlesSqueeze: Bool
    let onDoubleTap: (() -> Void)?
    let menu: () -> MenuContent

    func body(content: Content) -> some View {
        content
            .environment(\.showGamePencilMenu, GamePencilMenuAction(present: present(at:)))
            .coordinateSpace(.named(GamePencil.coordinateSpace))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .onPencilDoubleTap { _ in
                guard doubleTapAction != .ignore, isEnabled, let onDoubleTap else { return }
                onDoubleTap()
            }
            .onPencilSqueeze { phase in
                guard handlesSqueeze, squeezeAction != .ignore, isEnabled,
                      case let .ended(value) = phase else { return }
                anchor = .point(value.hoverPose?.anchor ?? .center)
                isPresented = true
            }
            .popover(isPresented: $isPresented, attachmentAnchor: anchor) {
                PencilActionList(dismiss: { isPresented = false }) {
                    Label("Apple Pencil", systemImage: "applepencil")
                        .font(.headline)
                        .padding(.bottom, 2)
                    menu()
                }
                .presentationCompactAdaptation(.popover)
            }
    }

    private func present(at point: CGPoint?) {
        guard isEnabled, squeezeAction != .ignore else { return }
        if let point, size.width > 0, size.height > 0 {
            anchor = .point(UnitPoint(x: point.x / size.width, y: point.y / size.height))
        } else {
            anchor = .point(.center)
        }
        isPresented = true
    }
}

extension View {
    /// Adds the shared Apple Pencil behavior to a game screen (see `GamePencil`).
    /// - Parameters:
    ///   - isEnabled: Whether a round is in play; Pencil does nothing on the start screen.
    ///   - handlesSqueeze: Pass `false` when views inside handle the squeeze themselves and call
    ///     `showGamePencilMenu` when it isn't on an answer.
    ///   - onDoubleTap: The safe next step right now, or `nil` when there isn't one.
    ///   - menu: The actions, in order: Next, hints, then `GameGiveUpButton`.
    func gamePencilActions<MenuContent: View>(
        isEnabled: Bool,
        handlesSqueeze: Bool = true,
        onDoubleTap: (() -> Void)?,
        @ViewBuilder menu: @escaping () -> MenuContent
    ) -> some View {
        modifier(GamePencilActionsModifier(
            isEnabled: isEnabled,
            handlesSqueeze: handlesSqueeze,
            onDoubleTap: onDoubleTap,
            menu: menu
        ))
    }
}
