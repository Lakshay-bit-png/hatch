import AppKit
import Observation

/// Tune played when a focus session completes. These ship with macOS.
enum CompletionSound: String, CaseIterable, Identifiable {
    case glass = "Glass"
    case ping = "Ping"
    case hero = "Hero"
    case submarine = "Submarine"
    case funk = "Funk"
    case blow = "Blow"
    case bottle = "Bottle"
    case tink = "Tink"
    case silent = "Silent"

    var id: String { rawValue }
    var label: String { rawValue }

    func play() {
        guard self != .silent, let sound = NSSound(named: rawValue) else { return }
        sound.stop()
        sound.play()
    }
}

/// A single focus countdown.
///
/// The remaining time is derived from an end date rather than decremented on a tick,
/// so it stays correct even if the timer fires late or the machine sleeps.
@Observable
@MainActor
final class PomodoroTimer {
    static let shared = PomodoroTimer()

    enum Phase: Equatable {
        case idle, running, paused, finished
    }

    private(set) var phase: Phase = .idle
    private(set) var remaining: TimeInterval = 25 * 60
    private(set) var duration: TimeInterval = 25 * 60

    private var endDate: Date?
    private var ticker: Timer?

    @ObservationIgnored var onTick: (() -> Void)?
    @ObservationIgnored var onFinish: (() -> Void)?

    var isRunning: Bool { phase == .running }
    var isActive: Bool { phase == .running || phase == .paused }

    private init() {}

    // MARK: - Controls

    func start(minutes: Int) {
        duration = TimeInterval(max(1, minutes) * 60)
        remaining = duration
        endDate = Date().addingTimeInterval(duration)
        phase = .running
        startTicker()
        onTick?()
    }

    func pause() {
        guard phase == .running else { return }
        remaining = max(0, endDate?.timeIntervalSinceNow ?? 0)
        endDate = nil
        phase = .paused
        stopTicker()
        onTick?()
    }

    func resume() {
        guard phase == .paused else { return }
        endDate = Date().addingTimeInterval(remaining)
        phase = .running
        startTicker()
        onTick?()
    }

    func reset(minutes: Int) {
        stopTicker()
        endDate = nil
        phase = .idle
        duration = TimeInterval(max(1, minutes) * 60)
        remaining = duration
        onTick?()
    }

    // MARK: - Progress

    /// 0 → 1 across the session. Computed from `date` so the orbit animates smoothly
    /// between ticks instead of stepping once a second.
    func progress(at date: Date = Date()) -> Double {
        guard duration > 0 else { return 0 }
        let left: TimeInterval
        if phase == .running, let endDate {
            left = max(0, endDate.timeIntervalSince(date))
        } else {
            left = remaining
        }
        return min(1, max(0, 1 - left / duration))
    }

    var displayTime: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard phase == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        onTick?()

        if remaining <= 0 {
            phase = .finished
            stopTicker()
            self.endDate = nil
            onFinish?()
        }
    }
}
