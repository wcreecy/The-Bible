import SwiftUI
import Testing
import UIKit
@testable import Bible

@MainActor
struct GameKeyboardInputTests {
    @Test
    func forwardsLowercaseUppercaseAndAnswerNumbers() {
        let responder = GameKeyboardResponder()
        responder.isActive = true
        var received: [String] = []
        responder.onKey = {
            received.append($0.characters)
            return .handled
        }

        responder.insertText("aZ14")

        #expect(received == ["a", "Z", "1", "4"])
    }

    @Test
    func normalizesReturnAndForwardsDeletion() {
        let responder = GameKeyboardResponder()
        responder.isActive = true
        var keys: [KeyEquivalent] = []
        responder.onKey = {
            keys.append($0.key)
            return .handled
        }

        responder.insertText("\r")
        responder.insertText("\n")
        responder.deleteBackward()

        #expect(keys == [.return, .return, .delete])
    }

    @Test
    func inactiveGameCannotReceiveInputOrClaimFocus() {
        let responder = GameKeyboardResponder()
        responder.isActive = true
        var received = 0
        responder.onKey = { _ in
            received += 1
            return .handled
        }
        responder.insertText("A")
        responder.isActive = false
        responder.insertText("B\n")
        responder.deleteBackward()

        #expect(received == 1)
        #expect(!responder.canBecomeFirstResponder)
        #expect(responder.keyCommands?.isEmpty == true)
    }

    @Test
    func suppliesNavigationCommandsAndSuppressesSystemKeyboard() {
        let responder = GameKeyboardResponder()
        responder.isActive = true
        let commands = responder.keyCommands ?? []

        #expect(commands.contains {
            $0.input == UIKeyCommand.inputUpArrow && $0.modifierFlags == .shift
        })
        #expect(commands.contains { $0.input == "\r" && $0.modifierFlags.isEmpty })
        #expect(commands.allSatisfy(\.wantsPriorityOverSystemBehavior))
        #expect(responder.inputView?.bounds.size == .zero)
    }
}
