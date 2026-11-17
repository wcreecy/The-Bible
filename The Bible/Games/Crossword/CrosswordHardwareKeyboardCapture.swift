import SwiftUI
import UIKit

/// A zero-size first responder that reliably receives iPad hardware-keyboard input.
/// SwiftUI's focusable board remains the visual focus owner; this bridge only forwards keys.
struct CrosswordHardwareKeyboardCapture: UIViewRepresentable {
    let isActive: Bool
    let focusRequestID: Int
    let onText: (String) -> Void
    let onDelete: () -> Void
    let onMove: (_ rowDelta: Int, _ columnDelta: Int) -> Void
    let onNextClue: (_ offset: Int) -> Void
    let onToggleDirection: () -> Void
    let onCheck: () -> Void
    let onEscape: () -> Void

    func makeUIView(context: Context) -> CrosswordHardwareKeyboardResponder {
        let view = CrosswordHardwareKeyboardResponder()
        configure(view)
        return view
    }

    func updateUIView(_ view: CrosswordHardwareKeyboardResponder, context: Context) {
        configure(view)

        if isActive {
            DispatchQueue.main.async {
                guard view.window != nil else { return }
                view.becomeFirstResponder()
            }
        } else if view.isFirstResponder {
            view.resignFirstResponder()
        }
    }

    private func configure(_ view: CrosswordHardwareKeyboardResponder) {
        view.onText = onText
        view.onDelete = onDelete
        view.onMove = onMove
        view.onNextClue = onNextClue
        view.onToggleDirection = onToggleDirection
        view.onCheck = onCheck
        view.onEscape = onEscape
        view.accessibilityElementsHidden = true

        // Reading this value makes every explicit focus request update the representable.
        _ = focusRequestID
    }
}

final class CrosswordHardwareKeyboardResponder: UIView, UIKeyInput {
    var onText: (String) -> Void = { _ in }
    var onDelete: () -> Void = {}
    var onMove: (_ rowDelta: Int, _ columnDelta: Int) -> Void = { _, _ in }
    var onNextClue: (_ offset: Int) -> Void = { _ in }
    var onToggleDirection: () -> Void = {}
    var onCheck: () -> Void = {}
    var onEscape: () -> Void = {}

    override var canBecomeFirstResponder: Bool { true }
    var hasText: Bool { true }

    /// The game supplies its own touch keyboard, so becoming first responder must not summon
    /// the system software keyboard when no hardware keyboard is attached.
    override var inputView: UIView? {
        UIView(frame: .zero)
    }

    override var keyCommands: [UIKeyCommand]? {
        [
            command(UIKeyCommand.inputUpArrow, action: #selector(moveUp)),
            command(UIKeyCommand.inputDownArrow, action: #selector(moveDown)),
            command(UIKeyCommand.inputLeftArrow, action: #selector(moveLeft)),
            command(UIKeyCommand.inputRightArrow, action: #selector(moveRight)),
            command("\t", action: #selector(nextClue)),
            command("\t", modifiers: .shift, action: #selector(previousClue)),
            command("\r", action: #selector(toggleDirection)),
            command("\r", modifiers: .command, action: #selector(checkPuzzle)),
            command(" ", action: #selector(toggleDirection)),
            command("\u{1B}", action: #selector(escape))
        ]
    }

    func insertText(_ text: String) {
        let letters = text.filter(\.isLetter)
        guard !letters.isEmpty else { return }
        onText(String(letters))
    }

    func deleteBackward() {
        onDelete()
    }

    private func command(
        _ input: String,
        modifiers: UIKeyModifierFlags = [],
        action: Selector
    ) -> UIKeyCommand {
        let command = UIKeyCommand(input: input, modifierFlags: modifiers, action: action)
        command.wantsPriorityOverSystemBehavior = true
        return command
    }

    @objc private func moveUp() { onMove(-1, 0) }
    @objc private func moveDown() { onMove(1, 0) }
    @objc private func moveLeft() { onMove(0, -1) }
    @objc private func moveRight() { onMove(0, 1) }
    @objc private func nextClue() { onNextClue(1) }
    @objc private func previousClue() { onNextClue(-1) }
    @objc private func toggleDirection() { onToggleDirection() }
    @objc private func checkPuzzle() { onCheck() }
    @objc private func escape() { onEscape() }
}
