import SwiftUI

struct ShelfView: View {
    @Bindable var store: ShelfStore
    @Bindable var state: PanelState

    @Environment(\.palette) private var palette
    @State private var hovered: UUID?

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                dropHint
            } else {
                list
                footer
            }
        }
        .onAppear { store.pruneMissing() }
    }

    // MARK: - Empty

    private var dropHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(palette.faint)

            Text("Nothing parked yet")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)

            Button(action: chooseFiles) {
                Text("Choose Files\u{2026}")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.background)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(palette.contrast))
            }
            .buttonStyle(.plain)

            Text("Drag any row back out to use the file")
                .font(.system(size: 9.5))
                .foregroundStyle(palette.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Standard open panel. The app is an accessory, so it has to be activated
    /// explicitly or the picker opens behind whatever is in front.
    private func chooseFiles() {
        let picker = NSOpenPanel()
        picker.allowsMultipleSelection = true
        picker.canChooseFiles = true
        picker.canChooseDirectories = true
        picker.resolvesAliases = true
        picker.prompt = "Add to Shelf"
        picker.message = "Choose files or folders to park on the shelf"
        // The panel floats at .screenSaver, which would otherwise cover the dialog.
        picker.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)

        state.isPresentingSheet = true
        NSApp.activate(ignoringOtherApps: true)

        picker.begin { response in
            MainActor.assumeIsolated {
                state.isPresentingSheet = false
                if response == .OK { store.add(picker.urls) }
                // Take focus back, so clicking away dismisses the panel as usual.
                state.requestFocus?()
            }
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(store.items) { item in
                    row(item)
                }
            }
            .padding(.vertical, 5)
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ item: ShelfItem) -> some View {
        let missing = !item.exists

        return HStack(spacing: 10) {
            Image(nsImage: store.icon(for: item))
                .resizable()
                .frame(width: 22, height: 22)
                .opacity(missing ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12))
                    .foregroundStyle(missing ? palette.faint : palette.text)
                    .lineLimit(1)
                Text(missing ? "Missing — file was moved or deleted" : detail(for: item))
                    .font(.system(size: 9.5))
                    .foregroundStyle(missing ? .orange.opacity(0.8) : palette.faint)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if hovered == item.id {
                iconButton("magnifyingglass", help: "Reveal in Finder") {
                    store.revealInFinder(item)
                }
                iconButton("xmark", help: "Remove from shelf") {
                    store.remove(item)
                }
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovered == item.id ? palette.selection : .clear)
        )
        .padding(.horizontal, 9)
        .contentShape(Rectangle())
        .onHover { hovering in
            hovered = hovering ? item.id : (hovered == item.id ? nil : hovered)
        }
        // Dragging the row hands the real file to Finder or any app that takes files.
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .onTapGesture { store.open(item) }
        .contextMenu {
            Button("Open") { store.open(item) }
            Button("Reveal in Finder") { store.revealInFinder(item) }
            Button("Remove") { store.remove(item) }
        }
    }

    /// Shows the parent folder only when another row shares this file's name.
    private func detail(for item: ShelfItem) -> String {
        guard store.ambiguousNames.contains(item.name) else { return item.detail }
        return "\(store.folderName(for: item)) \u{00B7} \(item.detail)"
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(palette.muted)
                .frame(width: 20, height: 20)
                .background(Circle().fill(palette.fill))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("\(store.items.count) parked \u{00B7} drag a row out to use it")
                .font(.system(size: 9.5))
                .foregroundStyle(palette.faint)

            Spacer(minLength: 0)

            Button(action: chooseFiles) {
                Text("Add\u{2026}")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(palette.fill))
            }
            .buttonStyle(.plain)

            Button {
                store.clear()
            } label: {
                Text("Clear")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(palette.fill))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
    }
}
