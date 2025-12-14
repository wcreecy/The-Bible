import SwiftUI

struct GridBoard: View {
    let size: Int
    let grid: [[Character]]
    let selectionStart: (row: Int, col: Int)?
    let selectionEnd: (row: Int, col: Int)?
    let foundCells: Set<String>
    let revealedWords: Set<String>
    let placed: [WordSearchEngine.PlacedWord]
    let backgroundColorForCell: (_ row: Int, _ col: Int) -> Color
    let onTapCell: (_ row: Int, _ col: Int) -> Void
    let onDragChanged: (_ cell: (row: Int, col: Int)) -> Void
    let onDragEnded: () -> Void
    let dynamicGridHeight: CGFloat

    private func strokeColorForCell(_ row: Int, _ col: Int) -> Color {
        let key = "\(row),\(col)"
        if foundCells.contains(key) { return Color.green.opacity(0.9) }
        if let start = selectionStart, let end = selectionEnd {
            func sign(_ x: Int) -> Int { x == 0 ? 0 : (x > 0 ? 1 : -1) }
            let dRow = end.row - start.row
            let dCol = end.col - start.col
            let dr = sign(dRow)
            let dc = sign(dCol)
            if dRow == 0 && dCol == 0 {
                if start.row == row && start.col == col { return Color.blue.opacity(0.9) }
            } else {
                var r = start.row
                var c = start.col
                while true {
                    if r == row && c == col { return Color.blue.opacity(0.9) }
                    if r == end.row && c == end.col { break }
                    r += dr; c += dc
                    if r < 0 || r >= size || c < 0 || c >= size { break }
                }
            }
        }
        return Color.black.opacity(0.1)
    }

    var body: some View {
        GeometryReader { geo in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let spacing: CGFloat = isPad ? 6 : 4
            let minCell: CGFloat = isPad ? 36 : 26
            let maxCell: CGFloat = isPad ? 58 : 36
            let horizontalPaddingBudget: CGFloat = 32

            let availableHeight = max(0, geo.size.height)
            let cellSizeFromHeight = (availableHeight - CGFloat(size - 1) * spacing) / CGFloat(size)

            let availableWidth = max(0, geo.size.width - horizontalPaddingBudget)
            let cellSizeFromWidth = (availableWidth - CGFloat(size - 1) * spacing) / CGFloat(size)

            let rawCellSize = min(cellSizeFromHeight, cellSizeFromWidth)
            let cellSize = min(max(rawCellSize, minCell), maxCell)

            let totalSize = CGFloat(size) * cellSize + CGFloat(size - 1) * spacing
            let letterFontSize: CGFloat = isPad ? min(26, cellSize * 0.72) : min(20, cellSize * 0.72)

            VStack(spacing: spacing) {
                ForEach(0..<size, id: \.self) { r in
                    HStack(spacing: spacing) {
                        ForEach(0..<size, id: \.self) { c in
                            let ch = grid[r][c]
                            Text(String(ch))
                                .font(.system(size: letterFontSize, weight: .bold, design: .monospaced))
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(backgroundColorForCell(r, c))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(strokeColorForCell(r, c), lineWidth: 1.5)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { onTapCell(r, c) }
                        }
                    }
                }
            }
            .frame(width: totalSize, height: totalSize, alignment: .topLeading)
            .position(x: geo.size.width / 2, y: min(totalSize / 2, geo.size.height / 2))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let cell = hitCell(from: value.location, container: geo.size, gridSize: totalSize, cellSize: cellSize, spacing: spacing) {
                            onDragChanged(cell)
                        }
                    }
                    .onEnded { _ in onDragEnded() }
            )
        }
        .frame(height: dynamicGridHeight)
    }

    private func hitCell(from point: CGPoint, container: CGSize, gridSize: CGFloat, cellSize: CGFloat, spacing: CGFloat) -> (row: Int, col: Int)? {
        let originX = (container.width - gridSize) / 2.0
        let originY: CGFloat = max(0, (container.height - gridSize) / 2.0)

        let localX = point.x - originX
        let localY = point.y - originY
        if localX < 0 || localY < 0 || localX > gridSize || localY > gridSize { return nil }

        let step = cellSize + spacing
        let col = Int(localX / step)
        let row = Int(localY / step)
        guard row >= 0, row < size, col >= 0, col < size else { return nil }

        let xInStep = localX - CGFloat(col) * step
        let yInStep = localY - CGFloat(row) * step
        guard xInStep <= cellSize, yInStep <= cellSize else { return nil }

        return (row, col)
    }
}
