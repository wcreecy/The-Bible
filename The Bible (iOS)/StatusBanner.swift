import SwiftUI

struct WordSearchStatusBanner: View {
    let timeUp: Bool
    let didWin: Bool

    var body: some View {
        Group {
            if timeUp {
                Text("Time’s up!").font(.headline).foregroundStyle(.red).transition(.opacity)
            } else if didWin {
                Text("You Win!").font(.headline).foregroundStyle(.green).transition(.opacity)
            }
        }
    }
}
