import Foundation
import Observation

@Observable
@MainActor
final class SnakeGame {
    static let shared = SnakeGame()

    struct Point: Hashable {
        var x: Int
        var y: Int
    }

    enum Direction {
        case up, down, left, right

        var delta: Point {
            switch self {
            case .up: return Point(x: 0, y: -1)
            case .down: return Point(x: 0, y: 1)
            case .left: return Point(x: -1, y: 0)
            case .right: return Point(x: 1, y: 0)
            }
        }

        var opposite: Direction {
            switch self {
            case .up: return .down
            case .down: return .up
            case .left: return .right
            case .right: return .left
            }
        }
    }

    enum Status {
        case idle, playing, paused, over
    }

    static let columns = 25
    static let rows = 13

    /// Head first.
    private(set) var body: [Point] = []
    private(set) var food = Point(x: 0, y: 0)
    private(set) var score = 0
    private(set) var best: Int
    private(set) var status: Status = .idle

    private var direction: Direction = .right
    /// Applied on the next tick, so two fast turns can't fold the snake onto itself.
    private var queued: Direction?
    private var ticker: Timer?

    private let bestKey = "game.snake.best"

    private init() {
        best = UserDefaults.standard.integer(forKey: bestKey)
        reset()
    }

    func reset() {
        stopTicker()
        let midY = Self.rows / 2
        body = [Point(x: 6, y: midY), Point(x: 5, y: midY), Point(x: 4, y: midY)]
        direction = .right
        queued = nil
        score = 0
        status = .idle
        placeFood()
    }

    func start() {
        guard status == .idle || status == .over else { return }
        if status == .over { reset() }
        status = .playing
        startTicker()
    }

    func togglePause() {
        switch status {
        case .playing:
            status = .paused
            stopTicker()
        case .paused:
            status = .playing
            startTicker()
        case .idle, .over:
            start()
        }
    }

    /// Called when the board goes off screen — the snake shouldn't keep crawling
    /// into a wall while nobody is looking at it.
    func pauseIfPlaying() {
        guard status == .playing else { return }
        status = .paused
        stopTicker()
    }

    func turn(_ new: Direction) {
        if status == .idle { start() }
        guard status == .playing else { return }
        // Ignore a reversal into the neck.
        guard new != direction.opposite else { return }
        queued = new
    }

    // MARK: - Loop

    private func tick() {
        guard status == .playing, let head = body.first else { return }

        if let queued { direction = queued }
        queued = nil

        let delta = direction.delta
        let next = Point(x: head.x + delta.x, y: head.y + delta.y)

        // Walls are solid — no wrapping.
        guard next.x >= 0, next.x < Self.columns, next.y >= 0, next.y < Self.rows else {
            return gameOver()
        }
        // The tail square is about to be vacated, so it isn't a collision.
        if body.dropLast().contains(next) { return gameOver() }

        body.insert(next, at: 0)

        if next == food {
            score += 1
            if score > best {
                best = score
                UserDefaults.standard.set(best, forKey: bestKey)
            }
            placeFood()
            startTicker()   // re-arm at the new, slightly faster interval
        } else {
            body.removeLast()
        }
    }

    private func gameOver() {
        status = .over
        stopTicker()
    }

    private func placeFood() {
        let occupied = Set(body)
        var free: [Point] = []
        for y in 0..<Self.rows {
            for x in 0..<Self.columns {
                let point = Point(x: x, y: y)
                if !occupied.contains(point) { free.append(point) }
            }
        }
        if let spot = free.randomElement() { food = spot }
    }

    /// Speeds up as the snake grows, with a floor so it stays playable.
    private var interval: TimeInterval {
        max(0.07, 0.15 - Double(score) * 0.004)
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
