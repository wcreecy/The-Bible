import SwiftUI

// Subviews for ScrambleGameView: the large split-layout timer, the prompt and answer
// tiles, the letter tray and its layout, and the action buttons.

struct ScrambleLargeTimerView: View {
    let timeRemaining: Int
    let timeLimit: Int?
    let tint: Color
    let isTimerDisabled: Bool
    @Binding var usesMutedStyle: Bool
    let onToggleTimer: () -> Void
    let onSwapSides: () -> Void

    private var isTimed: Bool { timeLimit != nil }

    private var displayTint: Color { isTimerDisabled ? .secondary : tint }

    private var vividTextColor: Color { .white }

    private var usesNeutralStyle: Bool {
        usesMutedStyle || isTimerDisabled
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: isTimerDisabled ? "timer.slash" : (isTimed ? "timer" : "infinity"))
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(isTimed ? (isTimerDisabled ? "Timer Off" : "Time Remaining") : "Untimed Mode")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(isTimed ? "\(timeRemaining)s" : "∞")
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isTimerDisabled ? "Timer off" : (isTimed ? "\(timeRemaining) seconds remaining" : "No time limit"))
            .contentShape(Rectangle())
            .onTapGesture {
                if isTimed {
                    onToggleTimer()
                }
            }
            .accessibilityAddTraits(isTimed ? .isButton : [])
            .accessibilityHint(
                isTimed
                    ? (isTimerDisabled ? "Tap to turn the timer on." : "Tap to turn the timer off.")
                    : ""
            )

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Swap card sides", systemImage: "arrow.left.arrow.right", action: onSwapSides)


                Button(
                    usesMutedStyle ? "Use vivid timer background" : "Use muted timer background",
                    systemImage: "circle.lefthalf.filled"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        usesMutedStyle.toggle()
                    }
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesNeutralStyle ? displayTint : vividTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background {
            if usesNeutralStyle {
                Color.clear
                    .heroCardSurface()
            } else {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .fill(displayTint)
            }
        }
        .overlay {
            if !usesNeutralStyle {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(vividTextColor.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: usesNeutralStyle ? .clear : displayTint.opacity(0.25), radius: 12, x: 0, y: 5)
        .padding(12)
        .animation(.easeInOut(duration: 0.25), value: timeRemaining)
    }
}

struct ScramblePrompt: View {
    let category: LocalizedStringKey
    let categoryName: String
    let reference: String?
    let answer: String
    let answerLength: Int
    let hintedLetters: [Character?]
    let isResolved: Bool
    let isIncorrect: Bool
    let timerTint: Color?
    let onShowReference: () -> Void

    private var categorySymbol: String {
        switch categoryName {
        case "Actions & Movement": "figure.walk"
        case "Animals & Creatures": "pawprint.fill"
        case "Bible book": "book.closed.fill"
        case "Body & Health": "heart.fill"
        case "Descriptions & Qualities": "sparkles"
        case "Directions & Positions": "arrow.up.left.and.arrow.down.right"
        case "Everyday word": "textformat"
        case "Faith & Worship": "hands.sparkles.fill"
        case "Family & Relationships": "person.2.circle.fill"
        case "Feelings & Character": "heart.text.square.fill"
        case "Food & Drink": "fork.knife"
        case "Law & Conflict": "exclamationmark.shield.fill"
        case "Nature & Weather": "cloud.sun.fill"
        case "Objects & Materials": "shippingbox.fill"
        case "People & Roles": "person.2.fill"
        case "Person": "person.fill"
        case "Place": "mappin.and.ellipse"
        case "Places & Structures": "building.2.fill"
        case "Plants & Farming": "leaf.fill"
        case "Speech & Learning": "text.bubble.fill"
        case "Time & Numbers": "clock.fill"
        default: "tag.fill"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Label(category, systemImage: categorySymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let reference {
                if isResolved {
                    Button(action: onShowReference) {
                        Label("Read \(reference)", systemImage: "book.closed")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    .accessibilityHint("Shows a preview of the source verse")
                } else {
                    Label(reference, systemImage: "book.closed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Build the word from the letter tiles.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 28)

            ScrambleAnswerTiles(
                answer: answer,
                answerLength: answerLength,
                hintedLetters: hintedLetters,
                isResolved: isResolved,
                isIncorrect: isIncorrect
            )
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(timerTint ?? Color.primary.opacity(0.12), lineWidth: timerTint == nil ? 1 : 2)
        }
    }
}

struct ScrambleAnswerTiles: View {
    let answer: String
    let answerLength: Int
    let hintedLetters: [Character?]
    let isResolved: Bool
    let isIncorrect: Bool
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let tileCount = max(answerLength, 1)
            let maximumSpacing = 7.0
            let minimumTileWidth = 24.0
            let spacing = min(
                maximumSpacing,
                max(
                    3,
                    (proxy.size.width - CGFloat(tileCount) * minimumTileWidth)
                        / CGFloat(max(tileCount - 1, 1))
                )
            )
            let tileWidth = max(
                1,
                min(
                    42,
                    (proxy.size.width - spacing * CGFloat(max(tileCount - 1, 0)))
                        / CGFloat(tileCount)
                )
            )
            let tileHeight = min(48, max(30, tileWidth + 6))

            HStack(spacing: spacing) {
                ForEach(0..<answerLength, id: \.self) { index in
                    let letter = index < answer.count ? String(answer[answer.index(answer.startIndex, offsetBy: index)]) : ""
                    let hint = index >= answer.count && index < hintedLetters.count ? hintedLetters[index].map(String.init) ?? "" : ""
                    Text(letter.isEmpty ? hint : letter)
                        .font(.title3.weight(.bold).monospaced())
                        .foregroundStyle(
                            letter.isEmpty && !hint.isEmpty
                                ? Color.secondary.opacity(0.55)
                                : (isResolved ? .secondary : .primary)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: tileWidth, height: tileHeight)
                        .background(
                            isIncorrect ? Color.orange.opacity(0.10) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    isIncorrect ? Color.orange : Color.primary.opacity(isResolved ? 0.08 : 0.15),
                                    lineWidth: isIncorrect ? 2 : 1
                                )
                        }
                        .offset(x: shakeOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 48)
        .task(id: isIncorrect) {
            guard isIncorrect else { return }

            for _ in 0..<3 {
                withAnimation(.easeInOut(duration: 0.08)) {
                    shakeOffset = 8
                }
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeInOut(duration: 0.08)) {
                    shakeOffset = -8
                }
                try? await Task.sleep(for: .milliseconds(80))
            }

            withAnimation(.easeInOut(duration: 0.08)) {
                shakeOffset = 0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Answer")
        .accessibilityValue(answer.isEmpty ? "Empty" : answer)
    }
}

struct ScrambleStrikeIndicator: View {
    let strikes: Int
    let limit: Int

    var body: some View {
        HStack(spacing: 6) {
            Label("Strikes", systemImage: "xmark.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(0..<limit, id: \.self) { index in
                Image(systemName: index < strikes ? "xmark.circle.fill" : "circle")
                    .foregroundStyle(index < strikes ? .red : .secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strikes")
        .accessibilityValue("\(strikes) of \(limit) used")
    }
}

struct ScrambleLetterTray: View {
    let letters: [Character]
    let selectedIndices: [Int]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrambleLetterFlowLayout {
            ForEach(letters.indices.filter { !selectedIndices.contains($0) }, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Text(String(letters[index]))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(ScrambleLetterTileStyle())
                .accessibilityLabel("\(String(letters[index])), available")
                .accessibilityHint("Double tap to add this letter.")
            }
        }
        .frame(maxWidth: 360, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct ScrambleLetterFlowLayout: Layout {
    private let tileSize: CGFloat = 48
    private let spacing: CGFloat = 10
    private let maximumWidth: CGFloat = 360

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = min(proposal.width ?? maximumWidth, maximumWidth)
        let columns = columnCount(for: width)
        let rows = max(1, Int(ceil(Double(subviews.count) / Double(columns))))
        let height = CGFloat(rows) * tileSize + CGFloat(rows - 1) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let columns = columnCount(for: bounds.width)

        for rowStart in stride(from: 0, to: subviews.count, by: columns) {
            let rowEnd = min(rowStart + columns, subviews.count)
            let count = rowEnd - rowStart
            let rowWidth = CGFloat(count) * tileSize + CGFloat(count - 1) * spacing
            let rowIndex = rowStart / columns
            let y = bounds.minY + CGFloat(rowIndex) * (tileSize + spacing)
            var x = bounds.midX - rowWidth / 2

            for index in rowStart..<rowEnd {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: tileSize, height: tileSize)
                )
                x += tileSize + spacing
            }
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        max(1, Int((width + spacing) / (tileSize + spacing)))
    }
}

struct ScrambleLetterTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct ScrambleActionButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let isEnabled: Bool
    var tint: Color = .pink
    var isProminent = false
    var isIncorrect = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isIncorrect ? "exclamationmark.circle.fill" : systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            isEnabled
                ? (isIncorrect ? Color.white : (isProminent ? Color.white : tint))
                : Color.secondary
        )
        .background(
            isEnabled
                ? (isIncorrect ? Color.orange : (isProminent ? Color.indigo : tint.opacity(0.10)))
                : Color.secondary.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isEnabled
                        ? (isIncorrect ? Color.orange : (isProminent ? Color.indigo : tint.opacity(0.45)))
                        : Color.secondary.opacity(0.25),
                    lineWidth: isIncorrect ? 2 : 1
                )
        }
        .disabled(!isEnabled)
        .accessibilityLabel(isIncorrect ? "Try again" : accessibilityLabel)
    }
}

struct ScrambleGlassActionButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let isEnabled: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.glass(.clear))
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .foregroundStyle(isEnabled ? tint : .secondary)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}
