import SwiftUI

/// Shows a popover at the Apple Pencil's tip when it's squeezed or double-tapped while
/// hovering over the view. It follows the person's Pencil settings: if they set the
/// squeeze or double-tap to "ignore" in Settings, that gesture does nothing here.
///
/// The gesture counts only when the Pencil is over this view, so lists can put it on every row.
/// The view the Pencil hovered over most recently, so when many rows share the gesture only
/// that one answers it.
@MainActor
private enum PencilHoverOwner {
    static var current: UUID?
}

private struct PencilPopoverModifier<PopoverContent: View>: ViewModifier {
    private let id = UUID()
    @Environment(\.preferredPencilDoubleTapAction) private var doubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var squeezeAction
    @State private var isHovering = false
    /// A squeeze can end the hover just before it's reported, so a hover that ended a moment ago
    /// still counts.
    @State private var lastHoverEnd: Date?
    @State private var isPresented = false
    @State private var anchor: PopoverAttachmentAnchor = .point(.center)

    let popoverContent: (_ dismiss: @escaping () -> Void) -> PopoverContent

    private static var hoverGrace: TimeInterval { 1.0 }

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                lastHoverEnd = hovering ? nil : Date()
                if hovering { PencilHoverOwner.current = id }
            }
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
        let justLeft = lastHoverEnd.map { Date().timeIntervalSince($0) < Self.hoverGrace } ?? false
        guard pose != nil || ((isHovering || justLeft) && PencilHoverOwner.current == id) else { return }
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

// MARK: - Lists and grids

/// Which item of a list or grid the Apple Pencil is over, or left a moment ago. Rows report
/// their hover to it; one handler on the whole list reads it when the Pencil is squeezed.
@MainActor
final class PencilHoverTracker<ID: Hashable> {
    private var current: ID?
    private var lastEnded: (id: ID, date: Date)?
    private let grace: TimeInterval
    private let now: () -> Date

    /// A squeeze can end the hover just before it's reported, so a hover that ended a moment
    /// ago still counts. `now` is injected by tests to verify the grace period deterministically.
    init(grace: TimeInterval = 1.5, now: @escaping () -> Date = Date.init) {
        self.grace = grace
        self.now = now
    }

    func hover(_ id: ID, isHovering: Bool) {
        if isHovering {
            current = id
            lastEnded = nil
        } else if current == id {
            current = nil
            lastEnded = (id, now())
        }
    }

    var target: ID? {
        if let current { return current }
        guard let lastEnded, now().timeIntervalSince(lastEnded.date) < grace else { return nil }
        return lastEnded.id
    }
}

private struct PencilTarget<ID: Hashable>: Identifiable {
    let value: ID
    var id: ID { value }
}

private struct PencilListPopoverModifier<ID: Hashable, PopoverContent: View>: ViewModifier {
    @Environment(\.preferredPencilDoubleTapAction) private var doubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var squeezeAction
    @State private var presented: PencilTarget<ID>?
    @State private var anchor: PopoverAttachmentAnchor = .point(.center)

    let tracker: PencilHoverTracker<ID>
    let popoverContent: (ID, _ dismiss: @escaping () -> Void) -> PopoverContent

    func body(content: Content) -> some View {
        content
            .onPencilDoubleTap { value in
                guard doubleTapAction != .ignore else { return }
                present(at: value.hoverPose)
            }
            .onPencilSqueeze { phase in
                guard squeezeAction != .ignore, case let .ended(value) = phase else { return }
                present(at: value.hoverPose)
            }
            .popover(item: $presented, attachmentAnchor: anchor) { target in
                popoverContent(target.value) { presented = nil }
                    .presentationCompactAdaptation(.popover)
            }
    }

    private func present(at pose: PencilHoverPose?) {
        guard let id = tracker.target else { return }
        anchor = .point(pose?.anchor ?? .center)
        presented = PencilTarget(value: id)
    }
}

extension View {
    /// Reports whether the Apple Pencil is over this row or cell to `tracker`.
    func pencilHover<ID: Hashable>(_ id: ID, in tracker: PencilHoverTracker<ID>) -> some View {
        modifier(PencilHoverFeedbackModifier(id: id, tracker: tracker))
    }

    /// Opens a popover for the hovered item when the Pencil is squeezed or double-tapped over
    /// this list or grid. One handler serves every row, which is more dependable than a handler
    /// on each one. `content` gets the item's ID and a closure that closes the popover.
    func pencilPopover<ID: Hashable, Content: View>(
        for tracker: PencilHoverTracker<ID>,
        @ViewBuilder content: @escaping (ID, _ dismiss: @escaping () -> Void) -> Content
    ) -> some View {
        modifier(PencilListPopoverModifier(tracker: tracker, popoverContent: content))
    }
}

private struct PencilHoverFeedbackModifier<ID: Hashable>: ViewModifier {
    let id: ID
    let tracker: PencilHoverTracker<ID>
    @State private var hoverCount = 0

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                if isHovering {
                    hoverCount += 1
                }
                tracker.hover(id, isHovering: isHovering)
            }
            // Lets iPadOS direct selection feedback to Apple Pencil Pro when it is available.
            .sensoryFeedback(.selection, trigger: hoverCount)
    }
}
