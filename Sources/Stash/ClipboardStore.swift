import AppKit
import Observation

/// The history itself: in-memory list, disk persistence, pinning, search and trimming.
@Observable
@MainActor
final class ClipboardStore {
    static let shared = ClipboardStore()

    private(set) var items: [ClipItem] = []
    var query: String = ""

    /// How many unpinned items to keep. Pinned items are never trimmed.
    var historyLimit: Int = 500 {
        didSet { trim(); scheduleSave() }
    }

    private var saveTask: Task<Void, Never>?

    // MARK: - Locations

    private static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Stash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var imagesFolder: URL = {
        let dir = folder.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static var historyFile: URL {
        folder.appendingPathComponent("history.json")
    }

    private init() {
        load()
    }

    // MARK: - Reading

    /// Items matching the current search, pinned ones floated to the front.
    var visibleItems: [ClipItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = trimmed.isEmpty
            ? items
            : items.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
        return matched.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    func image(for item: ClipItem) -> NSImage? {
        guard let name = item.imageFile else { return nil }
        return NSImage(contentsOf: Self.imagesFolder.appendingPathComponent(name))
    }

    // MARK: - Writing

    func add(_ item: ClipItem) {
        // A repeat copy moves the existing entry back to the top instead of duplicating.
        if let index = items.firstIndex(where: { $0.dedupeKey == item.dedupeKey }) {
            var existing = items.remove(at: index)
            existing.createdAt = Date()
            existing.sourceAppName = item.sourceAppName ?? existing.sourceAppName
            existing.sourceBundleID = item.sourceBundleID ?? existing.sourceBundleID
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        trim()
        scheduleSave()
    }

    func delete(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        removeImageFile(for: item)
        scheduleSave()
    }

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].pinned.toggle()
        scheduleSave()
    }

    /// Clears everything except pinned items.
    func clearUnpinned() {
        let doomed = items.filter { !$0.pinned }
        items.removeAll { !$0.pinned }
        doomed.forEach(removeImageFile(for:))
        scheduleSave()
    }

    func clearAll() {
        items.forEach(removeImageFile(for:))
        items.removeAll()
        scheduleSave()
    }

    private func trim() {
        var unpinnedSeen = 0
        var survivors: [ClipItem] = []
        var evicted: [ClipItem] = []

        for item in items {
            if item.pinned {
                survivors.append(item)
                continue
            }
            unpinnedSeen += 1
            if unpinnedSeen <= historyLimit {
                survivors.append(item)
            } else {
                evicted.append(item)
            }
        }

        guard !evicted.isEmpty else { return }
        items = survivors
        evicted.forEach(removeImageFile(for:))
    }

    private func removeImageFile(for item: ClipItem) {
        guard let name = item.imageFile else { return }
        try? FileManager.default.removeItem(at: Self.imagesFolder.appendingPathComponent(name))
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: Self.historyFile, options: .atomic)
        } catch {
            NSLog("Stash: could not save history — \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.historyFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ClipItem].self, from: data)) ?? []
    }
}
