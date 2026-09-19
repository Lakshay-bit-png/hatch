import Foundation
import Observation

@Observable
@MainActor
final class MemoryGame {
    static let shared = MemoryGame()

    struct Card: Identifiable, Equatable {
        let id = UUID()
        var symbol: String
        var isFaceUp = false
        var isMatched = false
    }

    private static let symbols = [
        "star.fill", "heart.fill", "bolt.fill", "leaf.fill", "moon.fill",
        "flame.fill", "drop.fill", "cloud.fill", "sun.max.fill", "diamond.fill"
    ]

    private(set) var cards: [Card] = []
    private(set) var moves = 0
    private(set) var best: Int?
    private(set) var isComplete = false

    /// The single face-up card waiting for its partner.
    private var pendingIndex: Int?
    private var isResolving = false

    private let bestKey = "game.memory.best"

    private init() {
        let stored = UserDefaults.standard.integer(forKey: bestKey)
        best = stored > 0 ? stored : nil
        newGame()
    }

    func newGame() {
        cards = (Self.symbols + Self.symbols)
            .shuffled()
            .map { Card(symbol: $0) }
        moves = 0
        isComplete = false
        pendingIndex = nil
        isResolving = false
    }

    func flip(_ id: UUID) {
        guard !isResolving, !isComplete,
              let index = cards.firstIndex(where: { $0.id == id }),
              !cards[index].isFaceUp, !cards[index].isMatched
        else { return }

        cards[index].isFaceUp = true

        guard let first = pendingIndex else {
            pendingIndex = index
            return
        }

        pendingIndex = nil
        moves += 1

        if cards[first].symbol == cards[index].symbol {
            cards[first].isMatched = true
            cards[index].isMatched = true
            checkForCompletion()
        } else {
            // Leave both visible briefly so the pair can be memorised.
            isResolving = true
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(650))
                guard let self else { return }
                self.cards[first].isFaceUp = false
                self.cards[index].isFaceUp = false
                self.isResolving = false
            }
        }
    }

    private func checkForCompletion() {
        guard cards.allSatisfy(\.isMatched) else { return }
        isComplete = true
        if best == nil || moves < best! {
            best = moves
            UserDefaults.standard.set(moves, forKey: bestKey)
        }
    }
}
