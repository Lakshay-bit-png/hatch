import AppKit
import Observation

/// A file parked on the shelf. Stored as a reference, not a copy — the shelf is a
/// staging area, so moving the original should be visible rather than hidden behind
/// a stale duplicate.
struct ShelfItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var path: String
    var size: Int64
    var isDirectory: Bool
    var addedAt: Date = Date()

    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }

    var detail: String {
        if isDirectory { return "Folder" }
        return ByteText.string(size)
    }
}

@Observable
@MainActor
final class ShelfStore {
    static let shared = ShelfStore()

    private(set) var items: [ShelfItem] = []

    private var saveTask: Task<Void, Never>?

    private static var file: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Stash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shelf.json")
    }

    private init() {
        load()
    }

    @discardableResult
    func add(_ urls: [URL]) -> Int {
        var added = 0

        for url in urls where url.isFileURL {
            let path = url.path

            // Verify first — nothing is mutated for a path that isn't really there.
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }

            // The same file again isn't a duplicate: drop the old row and re-add it on
            // top with fresh size and timestamp. Files that merely share a name are
            // left alone — they're different files, and the list disambiguates them.
            items.removeAll { $0.path == path }

            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

            items.insert(
                ShelfItem(path: path, size: size, isDirectory: isDirectory.boolValue),
                at: 0
            )
            added += 1
        }

        if added > 0 { scheduleSave() }
        return added
    }

    /// File names shared by more than one row. Those rows show their folder too,
    /// otherwise two different files look identical in the list.
    var ambiguousNames: Set<String> {
        var counts: [String: Int] = [:]
        for item in items { counts[item.name, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    func folderName(for item: ShelfItem) -> String {
        item.url.deletingLastPathComponent().lastPathComponent
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        scheduleSave()
    }

    func clear() {
        items.removeAll()
        scheduleSave()
    }

    /// Drops entries whose file has since been deleted.
    func pruneMissing() {
        let before = items.count
        items.removeAll { !$0.exists }
        if items.count != before { scheduleSave() }
    }

    func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func icon(for item: ShelfItem) -> NSImage {
        NSWorkspace.shared.icon(forFile: item.path)
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(items).write(to: Self.file, options: .atomic)
        } catch {
            NSLog("Stash: could not save shelf — \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.file) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ShelfItem].self, from: data)) ?? []
    }
}
