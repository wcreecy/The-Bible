import SwiftUI

struct WordSearchHeaderBox: View {
    let isTimedMode: Bool
    let timeUp: Bool
    let didWin: Bool
    let remainingSeconds: Int
    let pulseOn: Bool
    let verseRef: String
    let verseText: String
    let isFavorited: Bool
    let onToggleFavorite: () -> Void
    let timerTint: (Int) -> Color

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Word Search").font(.headline)
                    Spacer()
                    if isTimedMode && !timeUp {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                            Text(formattedTime(remainingSeconds)).monospacedDigit()
                        }
                        .font(.headline)
                        .foregroundStyle(timerTint(remainingSeconds))
                        .scaleEffect(pulseOn ? 1.12 : 1.0)
                        .animation(.easeInOut(duration: 0.25), value: pulseOn)
                    }
                }
                if !verseRef.isEmpty {
                    HStack(spacing: 8) {
                        Text(verseRef).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Button(action: { onToggleFavorite() }) {
                            Image(systemName: isFavorited ? "heart.fill" : "heart").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorited ? "Remove Favorite" : "Add to Favorites")
                    }
                }
                if !verseText.isEmpty {
                    Text("“\(verseText)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formattedTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}
