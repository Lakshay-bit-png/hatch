import AppKit
import SwiftUI

/// Small always-on-top capsule that hangs just under the notch while a focus
/// session is active. Clicking it pauses or resumes.
@MainActor
final class TimerHUDController {
    private var panel: NSPanel!
    private var container: HUDHitView!

    /// Size of the visible capsule — fixed, so hit testing stays exact.
    private static let capsule = CGSize(width: 96, height: 28)
    /// Slack around it for the drop-in animation.
    private static let pad: CGFloat = 14

    /// Lets the HUD stand down while the main panel is covering that area.
    var shouldHide: () -> Bool = { false }

    private let timer = PomodoroTimer.shared

    init() {
        build()
    }

    private func build() {
        let size = CGSize(
            width: Self.capsule.width + Self.pad * 2,
            height: Self.capsule.height + Self.pad * 2
        )

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let container = HUDHitView(frame: CGRect(origin: .zero, size: size))
        container.autoresizingMask = [.width, .height]
        container.activeRect = CGRect(
            x: Self.pad,
            y: Self.pad,
            width: Self.capsule.width,
            height: Self.capsule.height
        )

        let hosting = NSHostingView(
            rootView: TimerHUDView(timer: timer, size: Self.capsule) { [weak self] in
                self?.toggleTimer()
            }
        )
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)

        panel.contentView = container
        self.panel = panel
        self.container = container
    }

    /// Show or hide based on the timer's phase. Cheap enough to call on every tick.
    func update() {
        let wanted = timer.isActive && !shouldHide()

        if wanted {
            position()
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    private func toggleTimer() {
        switch timer.phase {
        case .running: timer.pause()
        case .paused: timer.resume()
        case .idle, .finished: break
        }
        update()
    }

    /// Centres the capsule under the notch — or under the menu bar on Macs without one.
    private func position() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let size = panel.frame.size

        let topInset = max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
        let notchBottom = screen.frame.maxY - topInset

        var centerX = screen.frame.midX
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            centerX = (left.maxX + right.minX) / 2
        }

        let x = centerX - size.width / 2
        // Capsule top sits 4pt under the notch; pad accounts for the window slack.
        let y = notchBottom - 4 - Self.capsule.height - Self.pad

        panel.setFrame(CGRect(x: x, y: y, width: size.width, height: size.height), display: false)
    }
}

/// Only the capsule itself takes clicks; the rest of the window passes through.
final class HUDHitView: NSView {
    var activeRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        guard activeRect.contains(local) else { return nil }
        return super.hitTest(point)
    }
}

struct TimerHUDView: View {
    @Bindable var timer: PomodoroTimer
    var size: CGSize
    var onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !timer.isRunning)) { context in
            capsule(progress: timer.progress(at: context.date))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func capsule(progress: Double) -> some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: max(0.001, progress))
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if timer.phase == .paused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 6, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 14, height: 14)

            Text(timer.displayTime)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: size.width, height: size.height)
        .background(
            Capsule().fill(.black)
        )
        .overlay {
            Capsule().strokeBorder(.white.opacity(hovering ? 0.22 : 0.10), lineWidth: 1)
        }
        .contentShape(Capsule())
        .onTapGesture(perform: onTap)
        .onHover { hovering = $0 }
        .help(timer.phase == .paused ? "Resume" : "Pause")
    }
}
