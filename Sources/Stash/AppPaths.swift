import Foundation

enum AppPaths {
    /// The app was called Clipdeck, then Hatch, before it was called Stash. Carry any
    /// existing clips, notes, tasks and shelf across instead of starting empty.
    static func migrateLegacyFolderIfNeeded() {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let current = base.appendingPathComponent("Stash", isDirectory: true)

        guard !manager.fileExists(atPath: current.path) else { return }

        // Newest name first, so the most recent data wins if several are present.
        for name in ["Hatch", "Clipdeck"] {
            let legacy = base.appendingPathComponent(name, isDirectory: true)
            guard manager.fileExists(atPath: legacy.path) else { continue }
            do {
                try manager.moveItem(at: legacy, to: current)
                NSLog("Stash: migrated data from the previous \(name) folder")
            } catch {
                NSLog("Stash: could not migrate \(name) data — \(error.localizedDescription)")
            }
            return
        }
    }
}
