import Foundation
import Observation

struct Note: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// First non-empty line, used as the row's heading.
    var title: String {
        let line = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let trimmed = (line.map(String.init) ?? "").trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled note" : trimmed
    }

    /// The rest of the note, flattened to one line for the row.
    var snippet: String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count > 1 else { return "" }
        return lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
}

@Observable
@MainActor
final class NoteStore {
    static let shared = NoteStore()

    private(set) var notes: [Note] = []

    private var saveTask: Task<Void, Never>?

    private static var file: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Stash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }

    private init() {
        load()
    }

    /// Most recently edited first.
    var ordered: [Note] {
        notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func create(text: String = "") -> Note {
        let note = Note(text: text)
        notes.insert(note, at: 0)
        scheduleSave()
        return note
    }

    func update(_ id: UUID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        guard notes[index].text != text else { return }
        notes[index].text = text
        notes[index].updatedAt = Date()
        scheduleSave()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Notes left completely empty aren't worth keeping around.
    func discardIfEmpty(_ id: UUID) {
        guard let note = notes.first(where: { $0.id == id }),
              note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        delete(id)
    }

    func note(_ id: UUID) -> Note? {
        notes.first { $0.id == id }
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
            try encoder.encode(notes).write(to: Self.file, options: .atomic)
        } catch {
            NSLog("Stash: could not save notes — \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.file) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        notes = (try? decoder.decode([Note].self, from: data)) ?? []
    }
}
