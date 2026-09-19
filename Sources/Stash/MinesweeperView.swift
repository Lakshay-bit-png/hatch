import SwiftUI

struct MinesweeperView: View {
    @Bindable var game: Minesweeper

    @Environment(\.palette) private var palette

    private let cell: CGFloat = 24
    private let gap: CGFloat = 2

    var body: some View {
        VStack(spacing: 7) {
            header
            board
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            counter(symbol: "flag.fill", value: "\(game.minesRemaining)")
            counter(symbol: "clock", value: "\(game.elapsed)s")

            if let best = game.best {
                counter(symbol: "trophy", value: "\(best)s")
            }

            Spacer(minLength: 0)

            Text(statusText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusColour)

            Button(action: game.newGame) {
                Text("New")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(palette.background)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(palette.contrast))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private func counter(symbol: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 8.5))
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(palette.muted)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Capsule().fill(palette.fill))
    }

    private var statusText: String {
        switch game.status {
        case .won: return "Cleared!"
        case .lost: return "Boom"
        case .playing, .idle: return ""
        }
    }

    private var statusColour: Color {
        game.status == .won ? .green : .red
    }

    // MARK: - Board

    private var board: some View {
        VStack(spacing: gap) {
            ForEach(0..<Minesweeper.rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<Minesweeper.columns, id: \.self) { column in
                        tile(row, column)
                    }
                }
            }
        }
        .padding(gap + 2)
        .background(RoundedRectangle(cornerRadius: 8).fill(palette.fill))
    }

    private func tile(_ row: Int, _ column: Int) -> some View {
        let square = game.grid[row][column]

        return RoundedRectangle(cornerRadius: 3)
            .fill(fill(for: square))
            .frame(width: cell, height: cell)
            .overlay { content(for: square) }
            .contentShape(Rectangle())
            .onTapGesture {
                if square.isRevealed {
                    game.chord(row: row, column: column)
                } else {
                    game.reveal(row: row, column: column)
                }
            }
            // Right-click to flag, the way the desktop original works.
            .contextMenu {
                Button(square.isFlagged ? "Remove flag" : "Flag") {
                    game.toggleFlag(row: row, column: column)
                }
            }
    }

    private func fill(for square: Minesweeper.Cell) -> Color {
        guard square.isRevealed else { return palette.selection }
        if square.isMine { return .red.opacity(0.65) }
        return palette.background.opacity(0.55)
    }

    @ViewBuilder
    private func content(for square: Minesweeper.Cell) -> some View {
        if square.isFlagged && !square.isRevealed {
            Image(systemName: "flag.fill")
                .font(.system(size: 10))
                .foregroundStyle(ClaudeMark.clay)
        } else if square.isRevealed {
            if square.isMine {
                Image(systemName: "burst.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
            } else if square.neighbours > 0 {
                Text("\(square.neighbours)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.numberColour(square.neighbours))
            }
        }
    }

    /// The familiar 1-8 colour code, brightened to read on a dark board.
    static func numberColour(_ count: Int) -> Color {
        switch count {
        case 1: return Color(red: 0.42, green: 0.66, blue: 1.00)
        case 2: return Color(red: 0.40, green: 0.80, blue: 0.45)
        case 3: return Color(red: 0.95, green: 0.45, blue: 0.42)
        case 4: return Color(red: 0.62, green: 0.55, blue: 0.95)
        case 5: return Color(red: 0.90, green: 0.60, blue: 0.30)
        case 6: return Color(red: 0.35, green: 0.80, blue: 0.80)
        case 7: return Color(white: 0.85)
        default: return Color(white: 0.60)
        }
    }
}
