import SwiftUI
import UIKit

/// Lets Apple Pencil handwriting (Scribble) fill crossword squares on iPad.
///
/// The squares are drawn by SwiftUI and aren't text fields, so this uses
/// `UIIndirectScribbleInteraction`: each letter square is a writable element. Writing on one
/// selects it and sends the recognized letters to the board, which types them along the answer.
/// The interaction sits on the window so finger taps still reach the board as usual; this view
/// itself never takes touches.
struct CrosswordScribbleCapture: UIViewRepresentable {
    let puzzle: CrosswordPuzzle
    let isActive: Bool
    let onSelect: (CrosswordPuzzle.Cell) -> Void
    let onText: (String) -> Void
    let onFinish: () -> Void

    func makeUIView(context: Context) -> CrosswordScribbleView {
        let view = CrosswordScribbleView()
        configure(view)
        return view
    }

    func updateUIView(_ view: CrosswordScribbleView, context: Context) {
        configure(view)
    }

    private func configure(_ view: CrosswordScribbleView) {
        view.puzzle = puzzle
        view.isActive = isActive
        view.onSelect = onSelect
        view.onText = onText
        view.onFinish = onFinish
    }
}

final class CrosswordScribbleView: UIView, UIIndirectScribbleInteractionDelegate {
    typealias ElementIdentifier = Int

    var puzzle: CrosswordPuzzle?
    var isActive = false
    var onSelect: (CrosswordPuzzle.Cell) -> Void = { _ in }
    var onText: (String) -> Void = { _ in }
    var onFinish: () -> Void = {}

    private lazy var interaction = UIIndirectScribbleInteraction(delegate: self)
    /// Receives the handwriting. It sits over the square being written on and never shows a keyboard.
    private let textField = ScribbleTextField()
    private var focusedElement: Int?

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

    // MARK: - Squares

    /// Each letter square's frame in this view, matching how `CrosswordBoardView` lays out the
    /// board: a square centered in the available space.
    private func frame(forElement element: Int) -> CGRect? {
        guard let puzzle, puzzle.size > 0 else { return nil }
        let side = min(bounds.width, bounds.height)
        let cellSize = side / CGFloat(puzzle.size)
        let origin = CGPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2)
        let cell = Self.cell(for: element, size: puzzle.size)
        guard puzzle.letter(at: cell) != nil else { return nil }
        return CGRect(
            x: origin.x + CGFloat(cell.col) * cellSize,
            y: origin.y + CGFloat(cell.row) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    private static func cell(for element: Int, size: Int) -> CrosswordPuzzle.Cell {
        CrosswordPuzzle.Cell(row: element / size, col: element % size)
    }

    private func frameInInteractionView(_ element: Int) -> CGRect {
        guard let frame = frame(forElement: element), let target = interaction.view else { return .zero }
        return convert(frame, to: target)
    }

    // MARK: - UIIndirectScribbleInteractionDelegate

    func indirectScribbleInteraction(
        _ interaction: any UIInteraction,
        requestElementsIn rect: CGRect,
        completion: @escaping ([Int]) -> Void
    ) {
        guard isActive, let puzzle, let target = self.interaction.view else {
            completion([])
            return
        }
        let localRect = convert(rect, from: target)
        let elements = (0..<(puzzle.size * puzzle.size)).filter { element in
            frame(forElement: element).map { $0.intersects(localRect) } ?? false
        }
        completion(elements)
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, isElementFocused elementIdentifier: Int) -> Bool {
        focusedElement == elementIdentifier && textField.isFirstResponder
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, frameForElement elementIdentifier: Int) -> CGRect {
        frameInInteractionView(elementIdentifier)
    }

    func indirectScribbleInteraction(
        _ interaction: any UIInteraction,
        focusElementIfNeeded elementIdentifier: Int,
        referencePoint focusReferencePoint: CGPoint,
        completion: @escaping ((any UIResponder & UITextInput)?) -> Void
    ) {
        guard let puzzle, let frame = frame(forElement: elementIdentifier) else {
            completion(nil)
            return
        }
        focusedElement = elementIdentifier
        onSelect(Self.cell(for: elementIdentifier, size: puzzle.size))
        textField.frame = frame
        textField.text = ""
        if !textField.isFirstResponder {
            textField.becomeFirstResponder()
        }
        completion(textField)
    }

    func indirectScribbleInteraction(_ interaction: any UIInteraction, didFinishWritingInElement elementIdentifier: Int) {
        textField.text = ""
        focusedElement = nil
        textField.resignFirstResponder()
        // Hands keyboard focus back to the board.
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
private final class ScribbleTextField: UITextField {
    override var inputView: UIView? {
        get { UIView(frame: .zero) }
        set {}
    }
}
