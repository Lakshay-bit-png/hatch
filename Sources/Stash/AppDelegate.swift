import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: PanelController!
    private var watcher: ClipboardWatcher!
    private var hotKey: HotKey?
    private var hud: TimerHUDController!

    private let store = ClipboardStore.shared
    private let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.historyLimit = settings.historyLimit

        panel = PanelController()
        panel.onActivate = { [weak self] item in
            guard let self else { return }
            if self.settings.autoPaste {
                Paster.paste(item, watcher: self.watcher)
            } else {
                Paster.copyToPasteboard(item, watcher: self.watcher)
            }
        }
        watcher = ClipboardWatcher()
        watcher.onCapture = { [weak self] item in
            self?.store.add(item)
        }
        watcher.isPaused = settings.capturePaused
        watcher.start()

        settings.onShortcutChanged = { [weak self] shortcut in
            self?.registerHotKey(shortcut)
        }
        settings.onPauseChanged = { [weak self] paused in
            self?.watcher.isPaused = paused
        }
        registerHotKey(settings.shortcut)

        hud = TimerHUDController()
        hud.shouldHide = { [weak self] in
            guard let self else { return true }
            return !self.settings.showTimerHUD || self.panel.isOpen
        }
        panel.onVisibilityChanged = { [weak self] in self?.hud.update() }

        let timer = PomodoroTimer.shared
        timer.reset(minutes: settings.timerMinutes)
        timer.onTick = { [weak self] in
            self?.updateStatusTitle()
            self?.hud.update()
        }
        timer.onFinish = { [weak self] in
            self?.settings.completionSound.play()
            self?.updateStatusTitle()
            self?.hud.update()
            self?.panel.flash("Focus session complete")
        }

        buildStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
        TodoStore.shared.saveNow()
        ShelfStore.shared.saveNow()
        NoteStore.shared.saveNow()
    }

    // MARK: - Hot key

    private func registerHotKey(_ shortcut: KeyShortcut) {
        hotKey = nil  // deinit unregisters the previous one
        hotKey = HotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            self?.togglePanel()
        }
    }

    // MARK: - Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image()
        button.image?.accessibilityDescription = "Stash"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusTitle()
    }

    /// Shows the countdown beside the icon while a session is active.
    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        let timer = PomodoroTimer.shared

        guard timer.isActive else {
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        let text = timer.phase == .paused ? timer.displayTime + " \u{23F8}" : timer.displayTime
        button.attributedTitle = NSAttributedString(
            string: " " + text,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)]
        )
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if wantsMenu {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        // Clicking the icon while the panel is open makes it resign key, which already
        // closes it — ignore the click that follows so it doesn't immediately reopen.
        guard Date().timeIntervalSince(panel.lastCloseAt) > 0.25 else { return }
        panel.toggle()
    }

    private func showMenu() {
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open Stash", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let focus = NSMenuItem(title: "Focus Timer", action: #selector(openTimer), keyEquivalent: "")
        focus.target = self
        menu.addItem(focus)

        let todo = NSMenuItem(title: "To-Do", action: #selector(openTodo), keyEquivalent: "")
        todo.target = self
        menu.addItem(todo)

        let notes = NSMenuItem(title: "Notes", action: #selector(openNotes), keyEquivalent: "")
        notes.target = self
        menu.addItem(notes)

        let shelf = NSMenuItem(title: "File Shelf", action: #selector(openShelf), keyEquivalent: "")
        shelf.target = self
        menu.addItem(shelf)

        let ask = NSMenuItem(title: "Ask Claude", action: #selector(openChat), keyEquivalent: "")
        ask.target = self
        menu.addItem(ask)

        let health = NSMenuItem(title: "System Health", action: #selector(openSystem), keyEquivalent: "")
        health.target = self
        menu.addItem(health)

        let pause = NSMenuItem(
            title: settings.capturePaused ? "Resume Capturing" : "Pause Capturing",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pause.target = self
        menu.addItem(pause)

        menu.addItem(.separator())

        let count = NSMenuItem(title: "\(store.items.count) clips stored", action: nil, keyEquivalent: "")
        count.isEnabled = false
        menu.addItem(count)

        let clear = NSMenuItem(title: "Clear Unpinned", action: #selector(clearUnpinned), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let quit = NSMenuItem(
            title: "Quit Stash",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        // Attaching the menu only for this click keeps left-click free for the panel.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Actions

    @objc private func openPanel() {
        panel.open()
    }

    @objc private func togglePause() {
        settings.capturePaused.toggle()
    }

    @objc private func clearUnpinned() {
        store.clearUnpinned()
    }

    @objc private func openTimer() {
        panel.open(page: .timer)
    }

    @objc private func openTodo() {
        panel.open(page: .todo)
    }

    @objc private func openNotes() {
        panel.open(page: .notes)
    }

    @objc private func openShelf() {
        panel.open(page: .shelf)
    }

    @objc private func openChat() {
        panel.open(page: .chat)
    }

    @objc private func openSystem() {
        panel.open(page: .system)
    }

    @objc private func openSettings() {
        panel.open(page: .settings)
    }
}
