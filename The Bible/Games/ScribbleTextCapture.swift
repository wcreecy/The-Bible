import SwiftUI
import UIKit

/// Lets Apple Pencil handwriting (Scribble) type into a game board on iPad, anywhere over the
/// view it covers. Recognized letters are passed on in order, so writing "GRACE" over WORD's
/// board fills the row.
///
/// The board isn't a text field, so this uses `UIIndirectScribbleInteraction` with the whole
/// area as one writable element. The interaction sits on the window, so finger taps still reach
/// the board as usual; this view itself never takes touches. Crossword uses a per-square version
/// of the same idea (`CrosswordScribbleCapture`).
struct ScribbleTextCapture: UIViewRepresentable {
    let isActive: Bool
    let onText: (String) -> Void
    var onFinish: () -> Void = {}

    func makeUIView(context: Context) -> ScribbleTextCaptureView {
        let view = ScribbleTextCaptureView()
        configure(view)
        return view
    }

    func updateUIView(_ view: ScribbleTextCaptureView, context: Context) {
        configure(view)
    }

    private func configure(_ view: ScribbleTextCaptureView) {
        view.isActive = isActive
        view.onText = onText
        view.onFinish = onFinish
    }
}

final class ScribbleTextCaptureView: UIView, UIIndirectScribbleInteractionDelegate {
    typealias ElementIdentifier = Int

    var isActive = false
    var onText: (String) -> Void = { _ in }
    var onFinish: () -> Void = {}

    private lazy var interaction = UIIndirectScribbleInteraction(delegate: self)
    /// Receives the handwriting and never shows a keyboard.
    private let textField = KeyboardlessTextField()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        accessibilityElementsHidden = true
        textField.alpha = 0.02
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .allCharacters
        textField.spellCheckingType = .no
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        addSubview(textField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        interaction.view?.removeInteraction(interaction)
        // On the window, so the board below keeps its finger taps.
        window?.addInteraction(interaction)
    }

    override func removeFromSuperview() {
        interaction.view?.removeInteraction(interaction)
        super.removeFromSuperview()
    }

    private var frameInInteractionView: CGRect {
        guard let target = interaction.view else { return .zero }
        return convert(bounds, to: target)
    }

    // MARK: - UIIndirectScribbleInteractionDelegate

    func indirectScribbleInteraction(
        _ interaction: any UIInteraction,
        requestElementsIn rect: CGRect,
        completion: @escaping ([Int]) -> Void
    ) {
        completion(isActive && frameInInteractionView.intersects(rect) ? [0] : [])
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, isElementFocused elementIdentifier: Int) -> Bool {
        textField.isFirstResponder
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, frameForElement elementIdentifier: Int) -> CGRect {
        frameInInteractionView
    }

    func indirectScribbleInteraction(
        _ interaction: any UIInteraction,
        focusElementIfNeeded elementIdentifier: Int,
        referencePoint focusReferencePoint: CGPoint,
        completion: @escaping ((any UIResponder & UITextInput)?) -> Void
    ) {
        textField.frame = bounds
        textField.text = ""
        if !textField.isFirstResponder {
            textField.becomeFirstResponder()
        }
        completion(textField)
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, didFinishWritingInElement elementIdentifier: Int) {
        textField.text = ""
        textField.resignFirstResponder()
        onFinish()
    }

    @objc private func textChanged() {
        let letters = (textField.text ?? "").filter(\.isLetter)
        textField.text = ""
        guard !letters.isEmpty else { return }
        onText(String(letters))
    }
}

/// A text field that never brings up the software keyboard; it only receives handwriting.
private final class KeyboardlessTextField: UITextField {
    override var inputView: UIView? {
        get { UIView(frame: .zero) }
        set {}
    }
}
