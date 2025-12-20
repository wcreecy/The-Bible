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

            // Use the actual container width; do NOT subtract a fixed padding budget here.
            let availableWidth = max(0, geo.size.width)
            let cellSizeFromWidth = (availableWidth - CGFloat(size - 1) * spacing) / CGFloat(size)

            // Height is still provided by the parent via dynamicGridHeight; we keep this for consistency.
            let availableHeight = max(0, geo.size.height)
            let cellSizeFromHeight = (availableHeight - CGFloat(size - 1) * spacing) / CGFloat(size)

            // Respect both constraints and clamp to min/max cell size.
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
            // Center horizontally, but keep the grid pinned to the top vertically.
            .position(x: geo.size.width / 2, y: totalSize / 2)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let p = value.location
                        if let cell = hitCellNearestCenter(from: p, cellSize: cellSize, spacing: spacing) {
                            onDragChanged(cell)
                        }
                    }
                    .onEnded { _ in onDragEnded() }
            )
        }
        .frame(height: dynamicGridHeight)
    }

    // Map a point (in this view’s local coordinates) to the nearest cell center.
    // Use (x - cellSize/2)/step rounded to remove rightward bias.
    private func hitCellNearestCenter(from point: CGPoint, cellSize: CGFloat, spacing: CGFloat) -> (row: Int, col: Int)? {
        let step = cellSize + spacing
        let total = CGFloat(size) * step - spacing // total grid extent along an axis

        // Clamp inside the grid’s bounds
        let x = min(max(point.x, 0), total - .ulpOfOne)
        let y = min(max(point.y, 0), total - .ulpOfOne)

        // Compute nearest index to the centers at k*step + cellSize/2
        let col = Int(((x - cellSize / 2) / step).rounded())
        let row = Int(((y - cellSize / 2) / step).rounded())

        guard row >= 0, row < size, col >= 0, col < size else { return nil }
        return (row, col)
    }
}
