import SwiftUI

struct SnakeView: View {
    @Bindable var game: SnakeGame

    @Environment(\.palette) private var palette

    private let cell: CGFloat = 16
    private let gap: CGFloat = 1

    var body: some View {
        VStack(spacing: 7) {
            header
            board.overlay { overlayMessage }
        }
        .onDisappear { game.pauseIfPlaying() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            pill("SCORE", game.score)
            pill("BEST", game.best)

            Spacer(minLength: 0)

            Button {
                game.reset()
                game.start()
            } label: {
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

    private func pill(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(palette.faint)
            Text("\(value)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.text)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 9)
        .background(Capsule().fill(palette.fill))
    }

    private var board: some View {
        Canvas { context, _ in
            for (index, point) in game.body.enumerated() {
                let rect = CGRect(
                    x: CGFloat(point.x) * (cell + gap),
                    y: CGFloat(point.y) * (cell + gap),
                    width: cell,
                    height: cell
                )
                // Head solid, tail fading out behind it.
                let fade = 1.0 - min(0.55, Double(index) / Double(max(game.body.count, 1)) * 0.75)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 3),
                    with: .color(index == 0 ? ClaudeMark.clay : ClaudeMark.clay.opacity(fade))
                )
            }

            let foodRect = CGRect(
                x: CGFloat(game.food.x) * (cell + gap) + 3,
                y: CGFloat(game.food.y) * (cell + gap) + 3,
                width: cell - 6,
                height: cell - 6
            )
            context.fill(Path(ellipseIn: foodRect), with: .color(.white))
        }
        .frame(
            width: CGFloat(SnakeGame.columns) * (cell + gap) - gap,
            height: CGFloat(SnakeGame.rows) * (cell + gap) - gap
        )
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 8).fill(palette.fill))
    }

    @ViewBuilder
    private var overlayMessage: some View {
        switch game.status {
        case .idle:
            message("Press an arrow key to start")
        case .paused:
            message("Paused — Space to resume")
        case .over:
            VStack(spacing: 6) {
                Text("Game over")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text("Score \(game.score)")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)
                Text("Space to play again")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.faint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .playing:
            EmptyView()
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(palette.muted)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(Capsule().fill(palette.background.opacity(0.85)))
    }
}
