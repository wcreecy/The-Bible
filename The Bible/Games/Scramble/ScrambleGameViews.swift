import SwiftUI

// Subviews for ScrambleGameView: the large split-layout timer, the prompt and answer
// tiles, dragging letters around the board, the letter tray and its layout, and the
// action buttons.

struct ScrambleLargeTimerView: View {
    let timeRemaining: Int
    let timeLimit: Int?
    let tint: Color
    let isTimerDisabled: Bool
    /// The verse clue, or the whole verse once solved, using the panel's spare room.
    let verse: GameVerse?
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

            if let verse {
                GameVerseCard(verse: verse)
                    .frame(maxWidth: 420)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

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
        .animation(.snappy, value: verse)
    }
}

struct ScramblePrompt<Tiles: View>: View {
    let category: LocalizedStringKey
    let categoryName: String
    let reference: String?
    let isResolved: Bool
    /// The verse clue, or the whole verse once solved. Nil when the iPad panel shows it instead.
    let verse: GameVerse?
    let timerTint: Color?
    let onShowReference: () -> Void
    @ViewBuilder let tiles: Tiles

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

            if let verse {
                GameVerseCard(verse: verse)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            Spacer(minLength: 28)

            tiles
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
        .animation(.snappy, value: verse)
    }
}

/// Where each answer square and tray tile sits, and the letter being dragged, so a drag or an
/// Apple Pencil squeeze can tell what's under it. Frames are in the board's coordinate space.
@Observable
final class ScrambleBoardLayout {
    static let coordinateSpace = "scrambleBoard"

    enum Target: Hashable {
        case square(Int)
        case trayTile(Int)
        /// The tray itself, including the gaps left by placed letters.
        case tray
    }

    struct Drag: Equatable {
        let source: ScrambleGameViewModel.TileSource
        let letter: Character
        var location: CGPoint
        var target: Target?
    }

    var drag: Drag?
    /// Written on every layout pass, so it's left out of observation.
    @ObservationIgnored var frames: [Target: CGRect] = [:]

    /// What's at `point`. Squares can be narrow on small phones, so each also catches the gap
    /// beside it and a band above and below; the nearest one wins.
    func target(at point: CGPoint) -> Target? {
        let squares = frames.compactMap { target, frame -> (Int, CGRect)? in
            guard case .square(let position) = target,
                  frame.insetBy(dx: -6, dy: -24).contains(point) else { return nil }
            return (position, frame)
        }
        if let nearest = squares.min(by: { abs($0.1.midX - point.x) < abs($1.1.midX - point.x) }) {
            return .square(nearest.0)
        }
        for (target, frame) in frames {
            if case .trayTile = target, frame.insetBy(dx: -4, dy: -4).contains(point) {
                return target
            }
        }
        if let tray = frames[.tray], tray.insetBy(dx: -16, dy: -16).contains(point) {
            return .tray
        }
        return nil
    }
}

extension View {
    /// Records this view's frame on the board so drags and Pencil squeezes can find it.
    func scrambleBoardTarget(_ target: ScrambleBoardLayout.Target, in layout: ScrambleBoardLayout) -> some View {
        onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(ScrambleBoardLayout.coordinateSpace))
        } action: { frame in
            layout.frames[target] = frame
        }
        .onDisappear {
            layout.frames[target] = nil
        }
    }
}

/// Drags a letter around the board. A custom gesture rather than system drag and drop, which
/// waits for a long press before lifting and feels slow in a game.
private struct ScrambleTileDrag: ViewModifier {
    let source: ScrambleGameViewModel.TileSource
    let letter: Character
    let layout: ScrambleBoardLayout
    let isEnabled: Bool
    let onDrop: (ScrambleGameViewModel.TileSource, ScrambleBoardLayout.Target?) -> Void
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(ScrambleBoardLayout.coordinateSpace))
                    .updating($isDragging) { _, isDragging, _ in isDragging = true }
                    .onChanged { value in
                        let target = layout.target(at: value.location)
                        if layout.drag?.source == source {
                            layout.drag?.location = value.location
                            layout.drag?.target = target
                        } else {
                            layout.drag = ScrambleBoardLayout.Drag(
                                source: source,
                                letter: letter,
                                location: value.location,
                                target: target
                            )
                        }
                    }
                    .onEnded { value in
                        layout.drag = nil
                        onDrop(source, layout.target(at: value.location))
                    },
                isEnabled: isEnabled
            )
            .onChange(of: isDragging) { _, isDragging in
                // A drag the system cancels never reaches onEnded, so put the letter down here.
                if !isDragging, layout.drag?.source == source {
                    layout.drag = nil
                }
            }
    }
}

extension View {
    func scrambleTileDrag(
        _ source: ScrambleGameViewModel.TileSource,
        letter: Character,
        layout: ScrambleBoardLayout,
        isEnabled: Bool,
        onDrop: @escaping (ScrambleGameViewModel.TileSource, ScrambleBoardLayout.Target?) -> Void
    ) -> some View {
        modifier(ScrambleTileDrag(source: source, letter: letter, layout: layout, isEnabled: isEnabled, onDrop: onDrop))
    }
}

/// The letter that follows a finger or pointer during a drag.
struct ScrambleFloatingTile: View {
    let letter: Character

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Text(String(letter))
            .font(.title3.weight(.bold))
            .frame(width: 48, height: 48)
            .background(.regularMaterial, in: shape)
            .overlay { shape.strokeBorder(Color.pink, lineWidth: 2) }
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .scaleEffect(1.1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct ScrambleAnswerTiles: View {
    let vm: ScrambleGameViewModel
    let layout: ScrambleBoardLayout
    let isIncorrect: Bool
    let isCorrect: Bool
    let onDrop: (ScrambleGameViewModel.TileSource, ScrambleBoardLayout.Target?) -> Void
    @State private var shakeOffset: CGFloat = 0
    @State private var showsCorrectHighlight = false

    var body: some View {
        let letters = vm.placedLetters
        let hints = vm.hintedLetters

        GeometryReader { proxy in
            let metrics = Self.tileMetrics(availableWidth: proxy.size.width, tileCount: max(letters.count, 1))

            HStack(spacing: metrics.spacing) {
                ForEach(letters.indices, id: \.self) { index in
                    square(
                        at: index,
                        letter: letters[index],
                        hint: index < hints.count ? hints[index] : nil,
                        count: letters.count,
                        metrics: metrics
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 56)
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
        .task(id: isCorrect) {
            guard isCorrect else {
                showsCorrectHighlight = false
                return
            }

            withAnimation(.easeInOut(duration: 0.18)) {
                showsCorrectHighlight = true
            }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                showsCorrectHighlight = false
            }
        }
        .animation(.snappy(duration: 0.2), value: vm.slots)
        .animation(.snappy(duration: 0.2), value: vm.heldTile)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Answer")
    }

    // The tile's size, letter, and colors are worked out in these helpers rather than inline
    // in `body`, which kept the type checker busy for seconds.

    private struct TileMetrics {
        let spacing: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    /// How one square looks, from most to least important.
    private enum SquareStyle {
        case correct, incorrect, dropTarget, held, cursor, hintedLetter, ghostHint, plain
    }

    /// Tiles as wide as fits (up to 48 points), with the gaps shrinking first for long words.
    private static func tileMetrics(availableWidth: CGFloat, tileCount: Int) -> TileMetrics {
        let count = CGFloat(tileCount)
        let maximumSpacing: CGFloat = 7
        let minimumTileWidth: CGFloat = 28
        let gaps = CGFloat(max(tileCount - 1, 1))
        let spacing = min(maximumSpacing, max(3, (availableWidth - count * minimumTileWidth) / gaps))
        let width = max(1, min(48, (availableWidth - spacing * CGFloat(max(tileCount - 1, 0))) / count))
        return TileMetrics(spacing: spacing, width: width, height: min(56, max(36, width + 8)))
    }

    private func style(at index: Int, letter: Character?, hint: Character?) -> SquareStyle {
        if showsCorrectHighlight { return .correct }
        if isIncorrect { return .incorrect }
        if layout.drag?.target == .square(index) { return .dropTarget }
        if vm.heldTile == .slot(index) { return .held }
        if vm.cursorPosition == index { return .cursor }
        if let letter, letter == hint { return .hintedLetter }
        if letter == nil, hint != nil { return .ghostHint }
        return .plain
    }

    /// How a square looks; `square(at:)` adds what it does.
    private func squareFace(at index: Int, letter: Character?, hint: Character?, metrics: TileMetrics) -> some View {
        let style = style(at: index, letter: letter, hint: hint)
        let isDragSource = layout.drag?.source == .slot(index)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return Text(letter.map { String($0) } ?? hint.map { String($0) } ?? "")
            .font(.title3.weight(.bold).monospaced())
            .foregroundStyle(textColor(style))
            .opacity(isDragSource ? 0.25 : 1)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: metrics.width, height: metrics.height)
            .background(fillColor(style), in: shape)
            .overlay {
                shape.strokeBorder(strokeColor(style), lineWidth: style == .plain ? 1 : 2)
            }
            // While a letter is held, every square shows it can take the drop.
            .overlay {
                if vm.heldTile != nil, style == .plain || style == .ghostHint {
                    shape.strokeBorder(Color.pink.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .scaleEffect(style == .held ? 1.08 : 1)
            .offset(x: shakeOffset, y: style == .held ? -4 : 0)
    }

    private func square(at index: Int, letter: Character?, hint: Character?, count: Int, metrics: TileMetrics) -> some View {
        let isResolved = vm.isCurrentWordResolved

        return squareFace(at: index, letter: letter, hint: hint, metrics: metrics)
            .contentShape(Rectangle())
            .onTapGesture { vm.tapSquare(index) }
            .scrambleTileDrag(
                .slot(index),
                letter: letter ?? " ",
                layout: layout,
                isEnabled: letter != nil && !isResolved,
                onDrop: onDrop
            )
            .scrambleBoardTarget(.square(index), in: layout)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Square \(index + 1)")
            .accessibilityValue(accessibilityValue(letter: letter, hint: hint))
            .accessibilityAddTraits(isResolved ? [] : .isButton)
            .accessibilityHint(isResolved ? "" : accessibilityHint(at: index, letter: letter))
            .accessibilityAction { vm.tapSquare(index) }
            .accessibilityActions {
                if letter != nil, !isResolved {
                    Button("Return to tray") { vm.returnToTray(index) }
                    ForEach(Array(0..<count).filter { $0 != index }, id: \.self) { destination in
                        Button("Move to square \(destination + 1)") {
                            vm.moveLetter(from: index, to: destination)
                        }
                    }
                }
            }
    }

    private func accessibilityValue(letter: Character?, hint: Character?) -> String {
        if let letter { return String(letter) }
        if let hint { return String(localized: "Empty, hint \(String(hint))") }
        return String(localized: "Empty")
    }

    private func accessibilityHint(at index: Int, letter: Character?) -> String {
        if vm.heldTile == .slot(index) { return String(localized: "Double tap to put the letter back down.") }
        if vm.heldTile != nil { return String(localized: "Double tap to drop the held letter here.") }
        if letter != nil { return String(localized: "Double tap to pick up this letter.") }
        return String(localized: "Double tap to fill this square next.")
    }

    private func textColor(_ style: SquareStyle) -> Color {
        switch style {
        case .correct: .green
        case .ghostHint: .yellow
        default: vm.isCurrentWordResolved ? .secondary : .primary
        }
    }

    private func fillColor(_ style: SquareStyle) -> Color {
        switch style {
        case .correct: Color.green.opacity(0.18)
        case .incorrect: Color.orange.opacity(0.10)
        case .dropTarget: Color.pink.opacity(0.18)
        case .held: Color.pink.opacity(0.10)
        case .hintedLetter, .ghostHint: Color.yellow.opacity(0.12)
        case .cursor, .plain: .clear
        }
    }

    private func strokeColor(_ style: SquareStyle) -> Color {
        switch style {
        case .correct: .green
        case .incorrect: .orange
        case .dropTarget, .held, .cursor: .pink
        case .hintedLetter, .ghostHint: Color.yellow.opacity(0.8)
        case .plain: Color.primary.opacity(vm.isCurrentWordResolved ? 0.08 : 0.15)
        }
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

/// The letter tiles. A placed tile leaves a gap where it was, so the others don't move and
/// there's a spot to put it back.
struct ScrambleLetterTray: View {
    let vm: ScrambleGameViewModel
    let layout: ScrambleBoardLayout
    let onDrop: (ScrambleGameViewModel.TileSource, ScrambleBoardLayout.Target?) -> Void

    var body: some View {
        let used = vm.usedTileIndices

        ScrambleLetterFlowLayout {
            ForEach(vm.shuffledLetters.indices, id: \.self) { index in
                if used.contains(index) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                } else {
                    tile(at: index)
                }
            }
        }
        .frame(maxWidth: 360, alignment: .center)
        .contentShape(Rectangle())
        // Tapping the tray, gaps included, puts a held letter back.
        .onTapGesture {
            vm.returnHeldTileToTray()
        }
        .scrambleBoardTarget(.tray, in: layout)
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.snappy(duration: 0.2), value: vm.shuffledLetters)
        .animation(.snappy(duration: 0.2), value: used)
    }

    private func tile(at index: Int) -> some View {
        let letter = vm.shuffledLetters[index]
        let isHeld = vm.heldTile == .tray(index)
        let isDragSource = layout.drag?.source == .tray(index)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return Text(String(letter))
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .frame(width: 48, height: 48)
            .background(isHeld ? Color.pink.opacity(0.10) : .clear, in: shape)
            .overlay {
                shape.strokeBorder(isHeld ? Color.pink : Color.primary.opacity(0.15), lineWidth: isHeld ? 2 : 1)
            }
            .opacity(isDragSource ? 0.25 : 1)
            .scaleEffect(isHeld ? 1.08 : 1)
            .offset(y: isHeld ? -4 : 0)
            .contentShape(shape)
            .hoverEffect(.lift)
            .onTapGesture { vm.selectLetter(index) }
            .scrambleTileDrag(
                .tray(index),
                letter: letter,
                layout: layout,
                isEnabled: !vm.isCurrentWordResolved,
                onDrop: onDrop
            )
            .scrambleBoardTarget(.trayTile(index), in: layout)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(String(letter)), available")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double tap to add this letter.")
            .accessibilityAction { vm.selectLetter(index) }
            .accessibilityActions {
                ForEach(vm.slots.indices, id: \.self) { position in
                    Button("Place in square \(position + 1)") {
                        vm.placeTile(index, at: position)
                    }
                }
            }
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

struct ScrambleActionButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let isEnabled: Bool
    var tint: Color = .pink
    var isProminent = false
    var isIncorrect = false
    var badgeText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isIncorrect ? "exclamationmark.circle.fill" : systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 48, height: 48)
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
        .overlay(alignment: .bottomTrailing) {
            if let badgeText {
                ScrambleActionBadge(text: badgeText, tint: tint, isEnabled: isEnabled)
                    .offset(x: 8, y: 8)
            }
        }
        .disabled(!isEnabled)
        .accessibilityLabel(isIncorrect ? "Try again" : accessibilityLabel)
    }
}

private struct ScrambleActionBadge: View {
    let text: String
    let tint: Color
    let isEnabled: Bool

    var body: some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(isEnabled ? Color.black.opacity(0.82) : Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                isEnabled ? tint : Color.secondary.opacity(0.18),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isEnabled ? Color.black.opacity(0.28) : Color.secondary.opacity(0.35),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(isEnabled ? 0.25 : 0.1), radius: 3, y: 1)
            .accessibilityHidden(true)
    }
}

struct ScrambleCheckAnswerButton: View {
    let isEnabled: Bool
    let requiresAnswerEdit: Bool
    let action: () -> Void

    private var title: LocalizedStringKey {
        requiresAnswerEdit ? "Edit answer to try again" : "Check Answer"
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: requiresAnswerEdit ? "pencil" : "checkmark.circle.fill")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 54)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.white : Color.secondary)
        .background(isEnabled ? Color.purple : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isEnabled ? Color.purple : Color.secondary.opacity(0.25), lineWidth: 1)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}
