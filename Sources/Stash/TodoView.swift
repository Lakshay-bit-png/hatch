import SwiftUI

struct TodoView: View {
    @Bindable var store: TodoStore

    @Environment(\.palette) private var palette
    @FocusState private var inputFocused: Bool
    @State private var draft = ""
    @State private var hovered: UUID?

    var body: some View {
        VStack(spacing: 0) {
            input
            Rectangle().fill(palette.divider).frame(height: 1)
            list
            summary
        }
        .onAppear { inputFocused = true }
    }

    private var input: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.faint)

            TextField("Add a task", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.text)
                .tint(palette.contrast)
                .focused($inputFocused)
                .onSubmit {
                    store.add(draft)
                    draft = ""
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }

    @ViewBuilder
    private var list: some View {
        if store.items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(palette.faint)
                Text("No tasks yet")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(store.ordered) { item in
                        row(item)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 10) {
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(item.done ? Color.green.opacity(0.85) : palette.faint)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(.system(size: 12.5))
                .foregroundStyle(item.done ? palette.faint : palette.text)
                .strikethrough(item.done, color: palette.faint)
                .lineLimit(1)

            Spacer(minLength: 6)

            if hovered == item.id {
                Button {
                    store.delete(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.faint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovered == item.id ? palette.selection : .clear)
        )
        .padding(.horizontal, 9)
        .contentShape(Rectangle())
        .onHover { hovering in
            hovered = hovering ? item.id : (hovered == item.id ? nil : hovered)
        }
        .onTapGesture { store.toggle(item) }
    }

    private var summary: some View {
        HStack(spacing: 8) {
            Text("\(store.openCount) open \u{00B7} \(store.doneCount) done")
                .font(.system(size: 9.5))
                .foregroundStyle(palette.faint)

            Spacer(minLength: 0)

            if store.doneCount > 0 {
                Button {
                    store.clearCompleted()
                } label: {
                    Text("Clear completed")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(palette.muted)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(palette.fill))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
    }
}
