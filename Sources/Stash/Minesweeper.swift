import Foundation
import Observation

@Observable
@MainActor
final class Minesweeper {
    static let shared = Minesweeper()

    enum Status {
        case idle, playing, won, lost
    }

    struct Cell: Equatable {
        var isMine = false
        var isRevealed = false
        var isFlagged = false
        var neighbours = 0
    }

    static let rows = 9
    static let columns = 9
    static let mines = 10

    private(set) var grid: [[Cell]] = []
    private(set) var status: Status = .idle
    private(set) var flagsUsed = 0
    private(set) var elapsed = 0
    private(set) var best: Int?

    private var ticker: Timer?
    private let bestKey = "game.mines.best"

    var minesRemaining: Int { Self.mines - flagsUsed }

    private init() {
        let stored = UserDefaults.standard.integer(forKey: bestKey)
        best = stored > 0 ? stored : nil
        newGame()
    }

    func newGame() {
        stopClock()
        grid = Array(
            repeating: Array(repeating: Cell(), count: Self.columns),
            count: Self.rows
        )
        status = .idle
        flagsUsed = 0
        elapsed = 0
    }

    // MARK: - Play

    func reveal(row: Int, column: Int) {
        guard status == .idle || status == .playing else { return }
        guard grid.indices.contains(row), grid[row].indices.contains(column) else { return }
        guard !grid[row][column].isFlagged, !grid[row][column].isRevealed else { return }

        // Mines are placed after the first tap, so the opening move is never a loss.
        if status == .idle {
            layMines(avoiding: (row, column))
            status = .playing
            startClock()
        }

        if grid[row][column].isMine {
            revealAllMines()
            status = .lost
            stopClock()
            return
        }

        flood(row: row, column: column)
        checkForWin()
    }

    func toggleFlag(row: Int, column: Int) {
        guard status == .idle || status == .playing else { return }
        guard !grid[row][column].isRevealed else { return }

        grid[row][column].isFlagged.toggle()
        flagsUsed += grid[row][column].isFlagged ? 1 : -1
    }

    /// Reveals the neighbours of an already-revealed number when enough flags are
    /// around it — the usual middle-click shortcut, here on a second tap.
    func chord(row: Int, column: Int) {
        guard status == .playing, grid[row][column].isRevealed, grid[row][column].neighbours > 0 else { return }

        let around = neighbours(row, column)
        let flagged = around.filter { grid[$0.0][$0.1].isFlagged }.count
        guard flagged == grid[row][column].neighbours else { return }

        for (r, c) in around where !grid[r][c].isFlagged && !grid[r][c].isRevealed {
            reveal(row: r, column: c)
            if status == .lost { return }
        }
    }

    // MARK: - Board

    private func layMines(avoiding safe: (Int, Int)) {
        var spots: [(Int, Int)] = []
        for r in 0..<Self.rows {
            for c in 0..<Self.columns {
                // Keep the first tap and its neighbours clear for a usable opening.
                if abs(r - safe.0) <= 1 && abs(c - safe.1) <= 1 { continue }
                spots.append((r, c))
            }
        }

        for (r, c) in spots.shuffled().prefix(Self.mines) {
            grid[r][c].isMine = true
        }

        for r in 0..<Self.rows {
            for c in 0..<Self.columns where !grid[r][c].isMine {
                grid[r][c].neighbours = neighbours(r, c).filter { grid[$0.0][$0.1].isMine }.count
            }
        }
    }

    private func neighbours(_ row: Int, _ column: Int) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let r = row + dr, c = column + dc
                if r >= 0, r < Self.rows, c >= 0, c < Self.columns { result.append((r, c)) }
            }
        }
        return result
    }

    /// Iterative flood fill — a recursive one can blow the stack on a big empty region.
    private func flood(row: Int, column: Int) {
        var queue = [(row, column)]

        while let (r, c) = queue.popLast() {
            guard !grid[r][c].isRevealed, !grid[r][c].isFlagged else { continue }
            grid[r][c].isRevealed = true
            guard grid[r][c].neighbours == 0 else { continue }
            queue.append(contentsOf: neighbours(r, c).filter { !grid[$0.0][$0.1].isRevealed })
        }
    }

    private func revealAllMines() {
        for r in 0..<Self.rows {
            for c in 0..<Self.columns where grid[r][c].isMine {
                grid[r][c].isRevealed = true
            }
        }
    }

    private func checkForWin() {
        let hidden = grid.flatMap { $0 }.filter { !$0.isRevealed && !$0.isMine }.count
        guard hidden == 0 else { return }

        status = .won
        stopClock()
        if best == nil || elapsed < best! {
            best = elapsed
            UserDefaults.standard.set(elapsed, forKey: bestKey)
        }
    }

    // MARK: - Clock

    private func startClock() {
        stopClock()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.status == .playing else { return }
                self.elapsed += 1
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopClock() {
        ticker?.invalidate()
        ticker = nil
    }
}
