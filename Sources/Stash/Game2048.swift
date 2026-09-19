import Foundation
import Observation

@Observable
@MainActor
final class Game2048 {
    static let shared = Game2048()

    enum Direction {
        case up, down, left, right
    }

    static let size = 4

    private(set) var grid: [[Int]] = []
    private(set) var score = 0
    private(set) var best: Int
    private(set) var isOver = false
    private(set) var reachedGoal = false

    /// Set briefly when a move merges tiles, so the view can pulse the score.
    private(set) var lastGain = 0

    private let bestKey = "game.2048.best"

    private init() {
        best = UserDefaults.standard.integer(forKey: bestKey)
        newGame()
    }

    func newGame() {
        grid = Array(repeating: Array(repeating: 0, count: Self.size), count: Self.size)
        score = 0
        lastGain = 0
        isOver = false
        reachedGoal = false
        spawn()
        spawn()
    }

    // MARK: - Moves

    @discardableResult
    func move(_ direction: Direction) -> Bool {
        guard !isOver else { return false }

        var moved = false
        var gained = 0

        for index in 0..<Self.size {
            let line = readLine(index, direction)
            let (collapsed, points) = collapse(line)
            if collapsed != line {
                moved = true
                writeLine(index, direction, collapsed)
            }
            gained += points
        }

        guard moved else { return false }

        score += gained
        lastGain = gained
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: bestKey)
        }
        if !reachedGoal, grid.contains(where: { $0.contains(2048) }) {
            reachedGoal = true
        }

        spawn()
        isOver = !canMove()
        return true
    }

    /// Reads one row or column as a line running in the direction of travel, so the
    /// collapse below only ever has to handle "slide everything left".
    private func readLine(_ index: Int, _ direction: Direction) -> [Int] {
        switch direction {
        case .left: return grid[index]
        case .right: return grid[index].reversed()
        case .up: return (0..<Self.size).map { grid[$0][index] }
        case .down: return (0..<Self.size).reversed().map { grid[$0][index] }
        }
    }

    private func writeLine(_ index: Int, _ direction: Direction, _ line: [Int]) {
        switch direction {
        case .left:
            grid[index] = line
        case .right:
            grid[index] = line.reversed()
        case .up:
            for row in 0..<Self.size { grid[row][index] = line[row] }
        case .down:
            for (offset, row) in (0..<Self.size).reversed().enumerated() {
                grid[row][index] = line[offset]
            }
        }
    }

    /// Slide, merge each pair once, slide again.
    private func collapse(_ line: [Int]) -> ([Int], Int) {
        let tiles = line.filter { $0 != 0 }
        var result: [Int] = []
        var gained = 0
        var i = 0

        while i < tiles.count {
            if i + 1 < tiles.count, tiles[i] == tiles[i + 1] {
                let merged = tiles[i] * 2
                result.append(merged)
                gained += merged
                i += 2
            } else {
                result.append(tiles[i])
                i += 1
            }
        }

        while result.count < Self.size { result.append(0) }
        return (result, gained)
    }

    // MARK: - Board state

    private func spawn() {
        var empty: [(Int, Int)] = []
        for row in 0..<Self.size {
            for column in 0..<Self.size where grid[row][column] == 0 {
                empty.append((row, column))
            }
        }
        guard let spot = empty.randomElement() else { return }
        grid[spot.0][spot.1] = Int.random(in: 0..<10) == 0 ? 4 : 2
    }

    private func canMove() -> Bool {
        for row in 0..<Self.size {
            for column in 0..<Self.size {
                let value = grid[row][column]
                if value == 0 { return true }
                if column + 1 < Self.size, grid[row][column + 1] == value { return true }
                if row + 1 < Self.size, grid[row + 1][column] == value { return true }
            }
        }
        return false
    }
}
