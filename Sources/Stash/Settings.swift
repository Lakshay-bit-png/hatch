import AppKit
import Carbon.HIToolbox
import Observation

/// A global keyboard shortcut, stored as Carbon key code + modifier mask.
struct KeyShortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let standard = KeyShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | optionKey)
    )

    /// True when at least one "real" modifier is held — without one, the shortcut
    /// would swallow ordinary typing system-wide.
    var isValid: Bool {
        modifiers & UInt32(cmdKey | controlKey | optionKey) != 0
    }

    var display: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += Self.keyName(for: keyCode)
        return result
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    static func keyName(for keyCode: UInt32) -> String {
        if let name = names[keyCode] { return name }
        return "Key \(keyCode)"
    }

    private static let names: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Escape): "⎋", UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ANSI_Grave): "`", UInt32(kVK_ANSI_Minus): "-",
        UInt32(kVK_ANSI_Equal): "=", UInt32(kVK_ANSI_LeftBracket): "[",
        UInt32(kVK_ANSI_RightBracket): "]", UInt32(kVK_ANSI_Backslash): "\\",
        UInt32(kVK_ANSI_Semicolon): ";", UInt32(kVK_ANSI_Quote): "'",
        UInt32(kVK_ANSI_Comma): ",", UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12"
    ]
}

/// Which appearance the panel uses.
enum Theme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// User preferences, backed by `UserDefaults`.
@Observable
@MainActor
final class Settings {
    static let shared = Settings()

    private enum Key {
        static let keyCode = "shortcut.keyCode"
        static let modifiers = "shortcut.modifiers"
        static let autoPaste = "behavior.autoPaste"
        static let historyLimit = "behavior.historyLimit"
        static let capturePaused = "behavior.capturePaused"
        static let theme = "appearance.theme"
        static let timerMinutes = "timer.minutes"
        static let timerSound = "timer.sound"
        static let timerHUD = "timer.hud"
    }

    /// Called when the shortcut changes so the hot key can be re-registered.
    @ObservationIgnored var onShortcutChanged: ((KeyShortcut) -> Void)?
    @ObservationIgnored var onPauseChanged: ((Bool) -> Void)?
    /// Called when the theme changes so the panel's appearance can be swapped.
    @ObservationIgnored var onThemeChanged: ((Theme) -> Void)?

    var shortcut: KeyShortcut {
        didSet {
            guard shortcut != oldValue else { return }
            defaults.set(Int(shortcut.keyCode), forKey: Key.keyCode)
            defaults.set(Int(shortcut.modifiers), forKey: Key.modifiers)
            onShortcutChanged?(shortcut)
        }
    }

    /// Press ⌘V for the user after choosing a clip (needs Accessibility permission).
    var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: Key.autoPaste) }
    }

    var historyLimit: Int {
        didSet {
            defaults.set(historyLimit, forKey: Key.historyLimit)
            ClipboardStore.shared.historyLimit = historyLimit
        }
    }

    var capturePaused: Bool {
        didSet {
            defaults.set(capturePaused, forKey: Key.capturePaused)
            onPauseChanged?(capturePaused)
        }
    }

    /// Length of one focus session.
    var timerMinutes: Int {
        didSet { defaults.set(timerMinutes, forKey: Key.timerMinutes) }
    }

    /// Show the countdown capsule under the notch while a session runs.
    var showTimerHUD: Bool {
        didSet { defaults.set(showTimerHUD, forKey: Key.timerHUD) }
    }

    /// Tune played when a session finishes.
    var completionSound: CompletionSound {
        didSet { defaults.set(completionSound.rawValue, forKey: Key.timerSound) }
    }

    var theme: Theme {
        didSet {
            guard theme != oldValue else { return }
            defaults.set(theme.rawValue, forKey: Key.theme)
            onThemeChanged?(theme)
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.keyCode: Int(KeyShortcut.standard.keyCode),
            Key.modifiers: Int(KeyShortcut.standard.modifiers),
            Key.autoPaste: true,
            Key.historyLimit: 500,
            Key.capturePaused: false,
            Key.theme: Theme.dark.rawValue,
            Key.timerMinutes: 25,
            Key.timerSound: CompletionSound.glass.rawValue,
            Key.timerHUD: true
        ])

        shortcut = KeyShortcut(
            keyCode: UInt32(defaults.integer(forKey: Key.keyCode)),
            modifiers: UInt32(defaults.integer(forKey: Key.modifiers))
        )
        autoPaste = defaults.bool(forKey: Key.autoPaste)
        historyLimit = defaults.integer(forKey: Key.historyLimit)
        capturePaused = defaults.bool(forKey: Key.capturePaused)
        theme = Theme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .dark
        timerMinutes = max(1, defaults.integer(forKey: Key.timerMinutes))
        completionSound = CompletionSound(rawValue: defaults.string(forKey: Key.timerSound) ?? "") ?? .glass
        showTimerHUD = defaults.bool(forKey: Key.timerHUD)
    }
}
