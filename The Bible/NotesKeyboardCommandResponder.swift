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
        view.isCommandHandlingEnabled = isEnabled

        DispatchQueue.main.async {
            if isEnabled {
                view.becomeFirstResponder()
            } else if view.isFirstResponder {
                view.resignFirstResponder()
            }
        }
    }

    @MainActor
    final class KeyCommandView: UIView {
        var moveSelection: ((Int) -> Void)?
        var requestDeletion: (() -> Void)?
        var isCommandHandlingEnabled = true

        override var canBecomeFirstResponder: Bool {
            isCommandHandlingEnabled
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
