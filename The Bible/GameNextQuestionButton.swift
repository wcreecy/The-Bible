import SwiftUI

/// Next, or See Results on the last question, for the question games (Quiz, Trivia, Verses).
struct GameNextQuestionButton: View {
    let isLastQuestion: Bool
    /// The game's color, used for See Results.
    let tint: Color
    let action: () -> Void

    var body: some View {
        if isLastQuestion {
            Button("See Results", systemImage: "flag.checkered", action: action)
                .buttonStyle(GameProminentButtonStyle(tint: tint))
        } else {
            Button("Next", systemImage: "arrow.right", action: action)
                .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
        }
    }
}

extension View {
    /// Pins the Next button to the bottom of the screen once a question is answered, so long
    /// questions and answers on iPhone never push it out of reach.
    func pinnedNextQuestionButton(
        isShown: Bool,
        isLastQuestion: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if isShown {
                GameNextQuestionButton(isLastQuestion: isLastQuestion, tint: tint, action: action)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.bar)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isShown)
    }
}
