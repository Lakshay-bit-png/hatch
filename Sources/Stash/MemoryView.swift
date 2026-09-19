import SwiftUI

struct MemoryView: View {
    @Bindable var game: MemoryGame

    @Environment(\.palette) private var palette

    private let columns = 5
    private let cardWidth: CGFloat = 62
    private let cardHeight: CGFloat = 46
    private let gap: CGFloat = 6

    var body: some View {
        VStack(spacing: 7) {
            header
            grid.overlay { if game.isComplete { done } }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            pill("MOVES", "\(game.moves)")
            if let best = game.best {
                pill("BEST", "\(best)")
            }

            Spacer(minLength: 0)

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

    private func pill(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(palette.faint)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.text)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 9)
        .background(Capsule().fill(palette.fill))
    }

    private var grid: some View {
        VStack(spacing: gap) {
            ForEach(0..<(game.cards.count / columns), id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if game.cards.indices.contains(index) {
                            card(game.cards[index])
                        }
                    }
                }
            }
        }
        .padding(gap)
        .background(RoundedRectangle(cornerRadius: 8).fill(palette.fill))
    }

    private func card(_ card: MemoryGame.Card) -> some View {
        let shown = card.isFaceUp || card.isMatched

        return RoundedRectangle(cornerRadius: 6)
            .fill(shown ? (card.isMatched ? ClaudeMark.clay.opacity(0.28) : palette.selection)
                        : palette.background.opacity(0.65))
            .frame(width: cardWidth, height: cardHeight)
            .overlay {
                if shown {
                    Image(systemName: card.symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(card.isMatched ? ClaudeMark.clay : palette.text)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(palette.divider, lineWidth: 1)
            }
            // Flipping a card rotates it rather than swapping the fill outright.
            .rotation3DEffect(.degrees(shown ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .animation(.easeInOut(duration: 0.25), value: shown)
            .contentShape(Rectangle())
            .onTapGesture { game.flip(card.id) }
    }

    private var done: some View {
        VStack(spacing: 6) {
            Text("All matched")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("\(game.moves) moves")
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
        .background(palette.background.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
