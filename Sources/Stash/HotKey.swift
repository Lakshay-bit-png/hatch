import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut.
///
/// Uses Carbon's `RegisterEventHotKey`, which — unlike a global `NSEvent` monitor —
/// works without Accessibility permission.
final class HotKey {
    private var ref: EventHotKeyRef?
    private let identifier: UInt32

    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextIdentifier: UInt32 = 1
    private static var handlerInstalled = false

    /// - Parameters:
    ///   - keyCode: a `kVK_` virtual key code.
    ///   - modifiers: Carbon modifier mask, e.g. `cmdKey | shiftKey`.
    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        HotKey.installHandlerIfNeeded()

        identifier = HotKey.nextIdentifier
        HotKey.nextIdentifier += 1

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_4950), id: identifier) // 'CLIP'
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr else {
            NSLog("Stash: could not register hot key (status \(status))")
            return nil
        }
        HotKey.handlers[identifier] = handler
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.handlers[identifier] = nil
    }

    fileprivate static func fire(_ identifier: UInt32) {
        handlers[identifier]?()
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &spec, nil, nil)
    }
}

/// C callback trampoline — must be a free function to be usable as a function pointer.
private let hotKeyCallback: EventHandlerUPP = { _, event, _ in
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let identifier = hotKeyID.id
    DispatchQueue.main.async {
        HotKey.fire(identifier)
    }
    return noErr
}
