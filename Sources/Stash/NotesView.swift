import SwiftUI

struct NotesView: View {
    @Bindable var store: NoteStore

    @Environment(\.palette) private var palette
    @FocusState private var editorFocused: Bool

    /// Which note is open. Nil means the list is showing.
    @State private var editing: UUID?
    @State private var draft = ""
    @State private var hovered: UUID?

    var body: some View {
        Group {
            if let id = editing {
                editor(id)
            } else {
                list
            }
        }
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: 0) {
            if store.notes.isEmpty {
                empty
            } else {
                rows
            }
            footer
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(palette.faint)
            Text("No notes yet")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
            Button(action: newNote) {
                Text("New Note")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.background)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(palette.contrast))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rows: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(store.ordered) { note in
                    row(note)
                }
            }
            .padding(.vertical, 5)
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ note: Note) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                if !note.snippet.isEmpty {
                    Text(note.snippet)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.faint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if hovered == note.id {
                Button {
                    store.delete(note.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.faint)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(palette.fill))
                }
                .buttonStyle(.plain)
            } else {
                Text(note.relativeTime)
                    .font(.system(size: 9.5))
                    .monospacedDigit()
                    .foregroundStyle(palette.faint)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovered == note.id ? palette.selection : .clear)
        )
        .padding(.horizontal, 9)
        .contentShape(Rectangle())
        .onHover { hovering in
            hovered = hovering ? note.id : (hovered == note.id ? nil : hovered)
        }
        .onTapGesture { open(note) }
        .contextMenu {
            Button("Copy text") { Paster.copyText(note.text) }
            Button("Delete") { store.delete(note.id) }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("\(store.notes.count) note\(store.notes.count == 1 ? "" : "s")")
                .font(.system(size: 9.5))
                .foregroundStyle(palette.faint)

            Spacer(minLength: 0)

            Button(action: newNote) {
                Text("New")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 9)
                    .background(Capsule().fill(palette.fill))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
    }

    // MARK: - Editor

    private func editor(_ id: UUID) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: closeEditor) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                        Text("Notes")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(palette.muted)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    Paster.copyText(draft)
                } label: {
                    Text("Copy")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(palette.muted)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 9)
                        .background(Capsule().fill(palette.fill))
                }
                .buttonStyle(.plain)

                Button {
                    store.delete(id)
                    editing = nil
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(palette.faint)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(palette.fill))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 30)

            TextEditor(text: $draft)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.text)
                .tint(palette.contrast)
                .scrollContentBackground(.hidden)
                .background(palette.background)
                .focused($editorFocused)
                .padding(.horizontal, 11)
                .onChange(of: draft) { _, text in
                    // Debounced inside the store, so every keystroke is cheap.
                    store.update(id, text: text)
                }
        }
        .onAppear {
            draft = store.note(id)?.text ?? ""
            editorFocused = true
        }
    }

    // MARK: - Actions

    private func newNote() {
        let note = store.create()
        draft = ""
        editing = note.id
    }

    private func open(_ note: Note) {
        draft = note.text
        editing = note.id
    }

    private func closeEditor() {
        if let id = editing {
            store.update(id, text: draft)
            store.discardIfEmpty(id)
        }
        editing = nil
    }
}
