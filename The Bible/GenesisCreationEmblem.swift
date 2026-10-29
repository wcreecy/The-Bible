import SwiftUI

/// The sun-and-leaf emblem shown beside Genesis in its chapter lists. The artwork is laid out
/// for the default 72-point size and scales with `size`.
struct GenesisCreationEmblem: View {
    var size: CGFloat = 72

    var body: some View {
        let scale = size / 72

        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "sun.max.fill")
                .font(.system(size: 32 * scale, weight: .medium))
                .foregroundStyle(.white)
                .offset(x: -8 * scale, y: -8 * scale)

            Image(systemName: "leaf.fill")
                .font(.system(size: 22 * scale, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))
                .rotationEffect(.degrees(-25))
                .offset(x: 12 * scale, y: 12 * scale)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
