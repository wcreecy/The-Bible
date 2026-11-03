import SwiftUI

struct ProgressRing<Label: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let tint: Color
    let track: Color
    let label: Label

    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        size: CGFloat = 56,
        tint: Color = .accentColor,
        track: Color = Color.primary.opacity(0.12),
        @ViewBuilder label: () -> Label
    ) {
        // Clamp to safe finite values
        let clampedProgress = progress.isFinite ? max(0, min(1, progress)) : 0
        let clampedLineWidth = lineWidth.isFinite ? max(0, lineWidth) : 0
        let clampedSize = size.isFinite ? max(0, size) : 0

        self.progress = clampedProgress
        self.lineWidth = clampedLineWidth
        self.size = clampedSize
        self.tint = tint
        self.track = track
        self.label = label()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Completion \(Int(round(progress * 100))) percent"))
    }
}
