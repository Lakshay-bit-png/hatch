import Foundation
import Observation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var done: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
}

/// The task list. Same shape as the clipboard store: in-memory list plus a
/// debounced JSON file beside it.
@Observable
@MainActor
final class TodoStore {
    static let shared = TodoStore()

    private(set) var items: [TodoItem] = []

    private var saveTask: Task<Void, Never>?

    private static var file: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Stash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.json")
    }

    private init() {
        load()
    }

    /// Open tasks first (newest on top), finished ones collected at the bottom.
    var ordered: [TodoItem] {
        items.sorted { lhs, rhs in
            if lhs.done != rhs.done { return !lhs.done }
            if lhs.done {
                return (lhs.completedAt ?? lhs.createdAt) > (rhs.completedAt ?? rhs.createdAt)
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var openCount: Int { items.filter { !$0.done }.count }
    var doneCount: Int { items.filter(\.done).count }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(TodoItem(text: trimmed), at: 0)
        scheduleSave()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].done.toggle()
        items[index].completedAt = items[index].done ? Date() : nil
        scheduleSave()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        scheduleSave()
    }

    func clearCompleted() {
        items.removeAll(where: \.done)
        scheduleSave()
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
            NSLog("Stash: could not save tasks — \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.file) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([TodoItem].self, from: data)) ?? []
    }
}
