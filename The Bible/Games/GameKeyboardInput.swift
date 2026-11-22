import SwiftUI
import UIKit

/// The same input description for physical keys and game-specific keyboard controls.
struct GameKeyboardPress {
    let key: KeyEquivalent
    let characters: String
    var modifiers: EventModifiers = []

    typealias Result = KeyPress.Result
}

extension View {
    /// Keeps typing available after touching game controls, without opening a system keyboard.
    /// Games retain their own visible letter keys, answer buttons, or board controls.
    func gameKeyboardInput(
        isActive: Bool,
        onKey: @escaping (GameKeyboardPress) -> GameKeyboardPress.Result
    ) -> some View {
        background {
            GameKeyboardCapture(isActive: isActive, onKey: onKey)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

private struct GameKeyboardCapture: UIViewRepresentable {
    let isActive: Bool
    let onKey: (GameKeyboardPress) -> GameKeyboardPress.Result

    func makeUIView(context: Context) -> GameKeyboardResponder {
        let view = GameKeyboardResponder()
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ view: GameKeyboardResponder, context: Context) {
        view.onKey = onKey
        view.isActive = isActive
        view.requestFocus()
    }

    static func dismantleUIView(_ view: GameKeyboardResponder, coordinator: ()) {
        view.isActive = false
        view.resignFirstResponder()
    }
}

final class GameKeyboardResponder: UIView, UIKeyInput {
    var isActive = false
    var onKey: (GameKeyboardPress) -> GameKeyboardPress.Result = { _ in .ignored }
    private let emptyInputView = UIView(frame: .zero)

    override var canBecomeFirstResponder: Bool { isActive }
    override var inputView: UIView? { emptyInputView }
    var hasText: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        requestFocus()
    }

    func requestFocus() {
        if !isActive {
            if isFirstResponder { resignFirstResponder() }
            return
        }
        // Wait until SwiftUI has installed the playing screen. Check again so a queued
        // request cannot reclaim input after a pause, sheet, or navigation change.
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.isActive, let window = self.window,
                  window.isKeyWindow, !self.hasPresentedController else { return }
            if !self.isFirstResponder { self.becomeFirstResponder() }
        }
    }

    private var hasPresentedController: Bool {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController,
               controller.presentedViewController != nil {
                return true
            }
            responder = current.next
        }
        return window?.rootViewController?.presentedViewController != nil
    }

    func insertText(_ text: String) {
        guard isActive else { return }
        for character in text {
            let key: KeyEquivalent = character == "\r" || character == "\n" ? .return : KeyEquivalent(character)
            _ = onKey(GameKeyboardPress(key: key, characters: String(character)))
        }
    }

    func deleteBackward() {
        guard isActive else { return }
        _ = onKey(GameKeyboardPress(key: .delete, characters: "\u{8}"))
    }

    override var keyCommands: [UIKeyCommand]? {
        guard isActive else { return [] }
        let inputs = [
            UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow,
            UIKeyCommand.inputLeftArrow, UIKeyCommand.inputRightArrow,
            "\r", "\u{1B}"
        ]
        return inputs.flatMap { input in
            [UIKeyModifierFlags(), .shift].map { modifiers in
                let command = UIKeyCommand(input: input, modifierFlags: modifiers, action: #selector(handleCommand))
                command.wantsPriorityOverSystemBehavior = true
                return command
            }
        }
    }

    @objc private func handleCommand(_ command: UIKeyCommand) {
        guard isActive, let input = command.input else { return }
        let key: KeyEquivalent
        switch input {
        case UIKeyCommand.inputUpArrow: key = .upArrow
        case UIKeyCommand.inputDownArrow: key = .downArrow
        case UIKeyCommand.inputLeftArrow: key = .leftArrow
        case UIKeyCommand.inputRightArrow: key = .rightArrow
        case "\r": key = .return
        case "\u{1B}": key = .escape
        default: return
        }
        _ = onKey(GameKeyboardPress(
            key: key,
            characters: input,
            modifiers: command.modifierFlags.contains(.shift) ? .shift : []
        ))
    }
}
