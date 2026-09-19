import AppKit
import SwiftUI
import Observation

enum PanelMetrics {
    static let width: CGFloat = 620
    static let rowHeight: CGFloat = 48
    /// How many clips are visible before the list starts scrolling.
    static let visibleRows = 7
    static let headerHeight: CGFloat = 50
    static let footerHeight: CGFloat = 29

    /// `border-radius: 0 0 28px 28px`, as maaa uses.
    static let bottomRadius: CGFloat = 28

    /// The clip page puts its search field above the list, inside the body.
    static let searchRowHeight: CGFloat = 44

    static var listHeight: CGFloat { rowHeight * CGFloat(visibleRows) }
    static var clipsListHeight: CGFloat { listHeight - searchRowHeight }
    static var height: CGFloat { headerHeight + listHeight + footerHeight + 22 }
    /// The panel unfurls in place, so the window needs no slack around it.
    static let windowPad: CGFloat = 0
}

/// Which page the panel is showing.
enum PanelMode: Equatable {
    case clips, timer, todo, notes, shelf, game, chat, system, settings
}

@Observable
@MainActor
final class PanelState {
    /// Drives the unfurl animation.
    var isVisible = false
    var selectedIndex = 0
    var toast: String?
    /// Timer and settings live inside the same panel as the clips.
    var mode: PanelMode = .clips
    /// While true the panel stops consuming keys, so the recorder can read them.
    var isRecordingShortcut = false
    /// True while a system dialog (the file picker) is in front of the panel.
    var isPresentingSheet = false
    /// Set by the controller so a page can hand focus back after a dialog closes.
    @ObservationIgnored var requestFocus: (() -> Void)?
    /// True only when the arrow keys moved the selection. Hovering must never
    /// scroll the list, or the scroll moves rows under the cursor and loops.
    var selectionFromKeyboard = false
}

/// Borderless panel that can take key focus without activating the app,
/// and routes the standard editing shortcuts to whatever is focused.
final class DropdownPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// A menu-bar-only app has no Edit menu, so ⌘A/⌘C/⌘V/⌘X/⌘Z would do nothing
    /// inside the search field. Forward them to the first responder by hand.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let shift = event.modifierFlags.contains(.shift)

        let selector: Selector?
        switch key {
        case "a": selector = #selector(NSText.selectAll(_:))
        case "c": selector = #selector(NSText.copy(_:))
        case "v": selector = #selector(NSText.paste(_:))
        case "x": selector = #selector(NSText.cut(_:))
        case "z": selector = shift ? Selector(("redo:")) : Selector(("undo:"))
        default: selector = nil
        }

        if let selector, NSApp.sendAction(selector, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let state = PanelState()

    private var panel: DropdownPanel!
    private var keyMonitor: Any?
    private var toastTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?

    private let store = ClipboardStore.shared

    var onActivate: ((ClipItem) -> Void)?
    /// Fires whenever the panel opens or closes, so the notch HUD can step aside.
    var onVisibilityChanged: (() -> Void)?

    var isOpen: Bool { state.isVisible }

    /// Used to ignore the status-item click that merely dismissed the panel.
    private(set) var lastCloseAt: Date = .distantPast

    override init() {
        super.init()
        buildPanel()
    }

    // MARK: - Setup

    private func buildPanel() {
        let size = CGSize(
            width: PanelMetrics.width + PanelMetrics.windowPad * 2,
            height: PanelMetrics.height + PanelMetrics.windowPad * 2
        )

        let panel = DropdownPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false          // flat edges — no halo around the panel
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .screenSaver   // above the menu bar, so it drops from the very top
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.delegate = self

        let hosting = NSHostingView(
            rootView: PanelView(
                state: state,
                store: store,
                settings: Settings.shared,
                onActivate: { [weak self] item in self?.activate(item) },
                onClose: { [weak self] in self?.close() }
            )
        )
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]

        panel.contentView = hosting
        self.panel = panel

        state.requestFocus = { [weak self] in
            self?.panel.makeKeyAndOrderFront(nil)
        }

        applyTheme(Settings.shared.theme)
        Settings.shared.onThemeChanged = { [weak self] theme in
            self?.applyTheme(theme)
        }
    }

    /// `nil` appearance means "follow the system".
    private func applyTheme(_ theme: Theme) {
        switch theme {
        case .system: panel.appearance = nil
        case .light: panel.appearance = NSAppearance(named: .aqua)
        case .dark: panel.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Open / close

    func open(mode: PanelMode = .clips) {
        closeTask?.cancel()
        position()

        store.query = ""
        state.selectedIndex = 0
        state.mode = mode

        panel.orderFrontRegardless()
        panel.makeKey()
        installKeyMonitor()

        // Let the window settle for one tick so the unfurl starts from zero height.
        DispatchQueue.main.async { [weak self] in
            withAnimation(Motion.unfurl) {
                self?.state.isVisible = true
            }
        }
        onVisibilityChanged?()
    }

    func close() {
        guard state.isVisible else { return }
        // A hidden panel shouldn't be running a game loop.
        SnakeGame.shared.pauseIfPlaying()
        lastCloseAt = Date()
        removeKeyMonitor()
        onVisibilityChanged?()

        withAnimation(Motion.collapse) {
            state.isVisible = false
        }

        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
            self?.store.query = ""
        }
    }

    func toggle() {
        if state.isVisible {
            close()
        } else {
            open()
        }
    }

    /// Opens straight onto one of the pages.
    func open(page: PanelMode) {
        if state.isVisible {
            withAnimation(Motion.swap) { state.mode = page }
        } else {
            open(mode: page)
        }
    }

    /// Centred on the display, with the panel's top edge flush against the very top of
    /// the screen — so it reads as sliding out from the top of the machine.
    private func position() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let width = panel.frame.width
        let height = panel.frame.height

        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY + PanelMetrics.windowPad - height

        panel.setFrame(CGRect(x: x, y: y, width: width, height: height), display: false)
    }

    // MARK: - Actions

    private func activate(_ item: ClipItem) {
        close()
        onActivate?(item)
    }

    func flash(_ message: String) {
        state.toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            self?.state.toast = nil
        }
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        // Only Sendable values cross into the main actor — NSEvent itself stays put.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let code = event.keyCode
            let flags = event.modifierFlags
            let handled = MainActor.assumeIsolated { self.handleKey(code: code, flags: flags) }
            return handled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the key was consumed.
    ///
    /// Only ↑/↓ are taken for list navigation — ←/→ stay free so the text cursor
    /// still works in the search field, as do all the ⌘-based editing shortcuts.
    private func handleKey(code: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        // The shortcut recorder needs the raw keys, so stay out of its way.
        guard !state.isRecordingShortcut else { return false }

        // Away from the clip list, Esc steps back and Space drives the timer.
        if state.mode != .clips {
            if code == 53 {
                withAnimation(Motion.swap) { state.mode = .clips }
                return true
            }
            if state.mode == .game {
                switch GamesState.shared.selected {
                case .twenty48:
                    let game = Game2048.shared
                    switch code {
                    case 126, 13: game.move(.up)     // up / W
                    case 125, 1:  game.move(.down)   // down / S
                    case 123, 0:  game.move(.left)   // left / A
                    case 124, 2:  game.move(.right)  // right / D
                    case 49: game.newGame()          // space
                    default: return false
                    }
                case .minesweeper:
                    guard code == 49 else { return false }
                    Minesweeper.shared.newGame()

                case .snake:
                    let snake = SnakeGame.shared
                    switch code {
                    case 126, 13: snake.turn(.up)
                    case 125, 1:  snake.turn(.down)
                    case 123, 0:  snake.turn(.left)
                    case 124, 2:  snake.turn(.right)
                    case 49: snake.togglePause()
                    default: return false
                    }

                case .memory:
                    guard code == 49 else { return false }
                    MemoryGame.shared.newGame()
                }
                return true
            }
            if state.mode == .timer, code == 49 { // space
                let timer = PomodoroTimer.shared
                switch timer.phase {
                case .running: timer.pause()
                case .paused: timer.resume()
                case .idle, .finished: timer.start(minutes: Settings.shared.timerMinutes)
                }
                return true
            }
            return false
        }

        let items = store.visibleItems

        switch code {
        case 53: // esc
            close()
            return true

        case 126: // up
            guard !items.isEmpty else { return true }
            state.selectionFromKeyboard = true
            state.selectedIndex = max(0, state.selectedIndex - 1)
            return true

        case 125: // down
            guard !items.isEmpty else { return true }
            state.selectionFromKeyboard = true
            state.selectedIndex = min(items.count - 1, state.selectedIndex + 1)
            return true

        case 36, 76: // return / enter
            guard items.indices.contains(state.selectedIndex) else { return true }
            activate(items[state.selectedIndex])
            return true

        case 51 where flags.contains(.command): // ⌘⌫ — delete selected
            guard items.indices.contains(state.selectedIndex) else { return true }
            store.delete(items[state.selectedIndex])
            state.selectedIndex = min(state.selectedIndex, max(0, store.visibleItems.count - 1))
            return true

        case 35 where flags.contains(.command): // ⌘P — pin selected
            guard items.indices.contains(state.selectedIndex) else { return true }
            store.togglePin(items[state.selectedIndex])
            return true

        default:
            return false
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Stay put only while a dialog we opened ourselves is in front — otherwise
        // the file picker taking focus would dismiss the panel behind it.
        guard !state.isPresentingSheet else { return }
        close()
    }
}
