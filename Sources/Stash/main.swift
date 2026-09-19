import AppKit

// Menu-bar-only app: no Dock icon, no main window. The UI drops down from the top.
// Top-level code runs on the main thread, so adopting the main actor here is safe.
// Runs before any store is touched, so they open the migrated folder.
MainActor.assumeIsolated { AppPaths.migrateLegacyFolderIfNeeded() }

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
