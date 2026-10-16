import SwiftUI
import UIKit

struct NotesKeyboardCommandResponder: UIViewRepresentable {
    let isEnabled: Bool
    let moveSelection: (Int) -> Void
    let requestDeletion: () -> Void

    func makeUIView(context: Context) -> KeyCommandView {
        KeyCommandView()
    }

    func updateUIView(_ view: KeyCommandView, context: Context) {
        view.moveSelection = moveSelection
        view.requestDeletion = requestDeletion

        // Claim focus only when commands turn on (a sheet closed or search ended), not on every
        // update, so typing in the search field or an editor never loses its keyboard.
        let wasEnabled = view.isCommandHandlingEnabled
        view.isCommandHandlingEnabled = isEnabled
        if isEnabled, !wasEnabled {
            view.claimFocusIfIdle()
        } else if !isEnabled, view.isFirstResponder {
            view.resignFirstResponder()
        }
    }

    @MainActor
    final class KeyCommandView: UIView {
        var moveSelection: ((Int) -> Void)?
        var requestDeletion: (() -> Void)?
        var isCommandHandlingEnabled = false

        override var canBecomeFirstResponder: Bool {
            isCommandHandlingEnabled
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { claimFocusIfIdle() }
        }

        /// Becomes first responder on the next run loop unless a text field or view is being edited.
        func claimFocusIfIdle() {
            Task { @MainActor [weak self] in
                guard let self, self.isCommandHandlingEnabled, self.window != nil, !self.isFirstResponder,
                      !(FirstResponderFinder.current() is UITextInput) else { return }
                self.becomeFirstResponder()
            }
        }

        override var keyCommands: [UIKeyCommand]? {
            guard isCommandHandlingEnabled else { return nil }

            return [
                command(
                    input: UIKeyCommand.inputUpArrow,
                    action: #selector(selectPreviousNote),
                    title: "Previous Note"
                ),
                command(
                    input: UIKeyCommand.inputDownArrow,
                    action: #selector(selectNextNote),
                    title: "Next Note"
                ),
                command(
                    input: "\u{8}",
                    action: #selector(deleteSelectedNote),
                    title: "Delete Selected Note"
                ),
                command(
                    input: UIKeyCommand.inputDelete,
                    action: #selector(deleteSelectedNote),
                    title: "Delete Selected Note"
                )
            ]
        }

        private func command(input: String, action: Selector, title: String) -> UIKeyCommand {
            let command = UIKeyCommand(
                title: title,
                action: action,
                input: input,
                modifierFlags: []
            )
            return command
        }

        @objc private func selectPreviousNote() {
            moveSelection?(-1)
        }

        @objc private func selectNextNote() {
            moveSelection?(1)
        }

        @objc private func deleteSelectedNote() {
            requestDeletion?()
        }
    }
}

/// Finds the current first responder by sending an action up the responder chain.
@MainActor
private enum FirstResponderFinder {
    static weak var found: UIResponder?

    static func current() -> UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.notesCaptureFirstResponder(_:)), to: nil, from: nil, for: nil)
        return found
    }
}

private extension UIResponder {
    @objc func notesCaptureFirstResponder(_ sender: Any?) {
        FirstResponderFinder.found = self
    }
}
