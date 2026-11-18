import SwiftUI

/// Shows a popover at the Apple Pencil's tip when it's squeezed or double-tapped while
/// hovering over the view. It follows the person's Pencil settings: if they set the
/// squeeze or double-tap to "ignore" in Settings, that gesture does nothing here.
///
/// The gesture counts only when the Pencil is over this view, so lists can put it on every row.
private struct PencilPopoverModifier<PopoverContent: View>: ViewModifier {
    @Environment(\.preferredPencilDoubleTapAction) private var doubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var squeezeAction
    @State private var isHovering = false
    @State private var isPresented = false
    @State private var anchor: PopoverAttachmentAnchor = .point(.center)

    let popoverContent: (_ dismiss: @escaping () -> Void) -> PopoverContent

    func body(content: Content) -> some View {
        content
            .onHover { isHovering = $0 }
            .onPencilDoubleTap { value in
                guard doubleTapAction != .ignore else { return }
                present(at: value.hoverPose)
            }
            .onPencilSqueeze { phase in
                guard squeezeAction != .ignore, case let .ended(value) = phase else { return }
                present(at: value.hoverPose)
            }
            .popover(isPresented: $isPresented, attachmentAnchor: anchor) {
                popoverContent { isPresented = false }
                    .presentationCompactAdaptation(.popover)
            }
    }

    /// An iPad that can't sense hover height gives no pose, so the popover opens at the
    /// middle of the view the pointer is over.
    private func present(at pose: PencilHoverPose?) {
        guard pose != nil || isHovering else { return }
        anchor = .point(pose?.anchor ?? .center)
        isPresented = true
    }
}

extension View {
    /// Opens `content` in a popover at the Pencil tip on a squeeze or double-tap over this view.
    /// `content` receives a closure that closes the popover.
    func pencilPopover<Content: View>(
        @ViewBuilder content: @escaping (_ dismiss: @escaping () -> Void) -> Content
    ) -> some View {
        modifier(PencilPopoverModifier(popoverContent: content))
    }
}

/// A column of actions for a Pencil popover, in the same buttons a long-press menu uses.
/// Each button closes the popover once it has run.
struct PencilActionList<Content: View>: View {
    let dismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .buttonStyle(PencilActionButtonStyle(dismiss: dismiss))
        // Menus, such as a Share submenu, look like the buttons beside them.
        .menuStyle(.button)
        .padding()
        .frame(width: 280)
    }
}

private struct PencilActionButtonStyle: ButtonStyle {
    let dismiss: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(configuration.role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
            // The action runs as the finger lifts; the popover closes right after.
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                if wasPressed && !isPressed { dismiss() }
            }
    }
}
