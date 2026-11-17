import SwiftUI
import UIKit

/// One pen stroke drawn over a verse image. Points and width are fractions of the canvas, so
/// the same stroke fits the preview, every format, and the full-size export.
struct InkStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    /// Line width as a fraction of the canvas width.
    var width: CGFloat
}

enum VerseImageInk {
    static let palette: [Color] = [.white, .black, .yellow, .orange, .red, .pink, .green, .blue]
    static let widthRange: ClosedRange<CGFloat> = 0.004...0.03

    /// Draws strokes, smoothed through the midpoints of the sampled points.
    static func draw(_ strokes: [InkStroke], in context: inout GraphicsContext, size: CGSize) {
        for stroke in strokes {
            let points = stroke.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
            let lineWidth = stroke.width * size.width
            guard let first = points.first else { continue }

            // A tap leaves a dot.
            if points.count == 1 {
                let dot = CGRect(x: first.x - lineWidth / 2, y: first.y - lineWidth / 2, width: lineWidth, height: lineWidth)
                context.fill(Path(ellipseIn: dot), with: .color(stroke.color))
                continue
            }

            var path = Path()
            path.move(to: first)
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                path.addQuadCurve(
                    to: CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2),
                    control: previous
                )
            }
            path.addLine(to: points[points.count - 1])
            context.stroke(
                path,
                with: .color(stroke.color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

/// The ink over the artwork. It's part of the artwork so the export includes it.
struct VerseInkLayer: View {
    let strokes: [InkStroke]

    var body: some View {
        Canvas { context, size in
            var context = context
            VerseImageInk.draw(strokes, in: &context, size: size)
        }
        .allowsHitTesting(false)
    }
}

/// Captures drawing touches over the preview. Apple Pencil always draws; a finger draws only
/// when `allowsFinger` is on, so a resting palm can be ignored.
struct InkCaptureView: UIViewRepresentable {
    var allowsFinger: Bool
    /// The stroke so far, as fractions of the view, each time it grows.
    var onChange: ([CGPoint]) -> Void
    var onEnd: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> InkTouchView {
        let view = InkTouchView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        return view
    }

    func updateUIView(_ view: InkTouchView, context: Context) {
        view.allowsFinger = allowsFinger
        view.onChange = onChange
        view.onEnd = onEnd
    }
}

final class InkTouchView: UIView {
    var allowsFinger = true
    var onChange: ([CGPoint]) -> Void = { _ in }
    var onEnd: ([CGPoint]) -> Void = { _ in }

    private var activeTouch: UITouch?
    private var points: [CGPoint] = []

    private func accepts(_ touch: UITouch) -> Bool {
        touch.type == .pencil || (allowsFinger && touch.type == .direct)
    }

    private func normalized(_ touch: UITouch) -> CGPoint {
        let location = touch.location(in: self)
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        return CGPoint(
            x: min(max(location.x / bounds.width, 0), 1),
            y: min(max(location.y / bounds.height, 0), 1)
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first(where: accepts) else { return }
        activeTouch = touch
        points = [normalized(touch)]
        onChange(points)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        // Coalesced touches keep the fast, fine detail of a Pencil stroke.
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            points.append(normalized(sample))
        }
        onChange(points)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        points.append(normalized(touch))
        finish()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        activeTouch = nil
        points = []
        onChange([])
    }

    private func finish() {
        let finished = points
        activeTouch = nil
        points = []
        onEnd(finished)
    }
}
