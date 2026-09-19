import SwiftUI

struct Game2048View: View {
    @Bindable var game: Game2048

    @Environment(\.palette) private var palette

    private let tile: CGFloat = 50
    private let gap: CGFloat = 6

    var body: some View {
        VStack(spacing: 8) {
            header
            board
                .overlay { if game.isOver { gameOver } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            scorePill("SCORE", game.score)
            scorePill("BEST", game.best)

            Spacer(minLength: 0)

            if game.reachedGoal {
                Text("2048!")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.background)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(Self.colour(for: 2048)))
            }

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

    private func scorePill(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(palette.faint)
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.text)
        }
        .frame(width: 56)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(palette.fill))
    }

    // MARK: - Board

    private var board: some View {
        VStack(spacing: gap) {
            ForEach(0..<Game2048.size, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<Game2048.size, id: \.self) { column in
                        cell(game.grid[row][column])
                    }
                }
            }
        }
        .padding(gap)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.fill))
    }

    private func cell(_ value: Int) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(value == 0 ? palette.fill.opacity(0.6) : Self.colour(for: value))
            .frame(width: tile, height: tile)
            .overlay {
                if value > 0 {
                    Text("\(value)")
                        .font(.system(size: value >= 1024 ? 16 : (value >= 128 ? 19 : 22),
                                      weight: .bold, design: .rounded))
                        .foregroundStyle(value <= 4 ? Color.white.opacity(0.85) : .white)
                        .minimumScaleFactor(0.6)
                }
            }
            // No sliding animation — tiles pop into their new value instead.
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: value)
    }

    /// Warm ramp built around the app's clay accent, so it reads on a dark panel.
    static func colour(for value: Int) -> Color {
        switch value {
        case 2: return Color(white: 0.30)
        case 4: return Color(white: 0.38)
        case 8: return Color(red: 0.80, green: 0.52, blue: 0.32)
        case 16: return Color(red: 0.84, green: 0.45, blue: 0.28)
        case 32: return Color(red: 0.86, green: 0.38, blue: 0.26)
        case 64: return Color(red: 0.88, green: 0.30, blue: 0.22)
        case 128: return Color(red: 0.88, green: 0.62, blue: 0.24)
        case 256: return Color(red: 0.89, green: 0.58, blue: 0.18)
        case 512: return Color(red: 0.90, green: 0.52, blue: 0.14)
        case 1024: return Color(red: 0.92, green: 0.46, blue: 0.10)
        default: return Color(red: 0.94, green: 0.40, blue: 0.06)
        }
    }

    private var gameOver: some View {
        VStack(spacing: 8) {
            Text("No moves left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("Score \(game.score)")
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)
            Button(action: game.newGame) {
                Text("Play again")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.background)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 14)
                    .background(Capsule().fill(palette.contrast))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
