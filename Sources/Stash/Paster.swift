import AppKit
import Carbon.HIToolbox

/// Puts an item back on the pasteboard, and optionally presses ⌘V for the user.
@MainActor
enum Paster {
    /// Straight text onto the pasteboard, used by the chat page.
    static func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copy only — always works, no permissions needed.
    static func copyToPasteboard(_ item: ClipItem, watcher: ClipboardWatcher?) {
        let pasteboard = NSPasteboard.general
        watcher?.suppressNextChange = true
        pasteboard.clearContents()

        switch item.kind {
        case .image:
            if let image = ClipboardStore.shared.image(for: item) {
                pasteboard.writeObjects([image])
            }
        case .file:
            let urls = item.text
                .split(separator: "\n")
                .map { URL(fileURLWithPath: String($0)) as NSURL }
            if urls.isEmpty {
                pasteboard.setString(item.text, forType: .string)
            } else {
                pasteboard.writeObjects(urls)
            }
        case .text, .url:
            pasteboard.setString(item.text, forType: .string)
        }
    }

    /// Copy, then synthesise ⌘V into the frontmost app. Needs Accessibility permission;
    /// without it the item is still on the pasteboard for a manual paste.
    static func paste(_ item: ClipItem, watcher: ClipboardWatcher?) {
        copyToPasteboard(item, watcher: watcher)

        guard hasAccessibilityPermission else { return }

        // Give the panel a beat to close and focus to return to the real app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sendCommandV()
        }
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Opens the Accessibility pane with our app prompted for approval.
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func sendCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKey = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
