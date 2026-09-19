import SwiftUI

struct PanelView: View {
    @Bindable var state: PanelState
    @Bindable var store: ClipboardStore
    @Bindable var settings: Settings
    var onActivate: (ClipItem) -> Void
    var onClose: () -> Void

    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var palette: Palette { Palette.resolved(for: colorScheme) }

    /// Square at the top so it sits flush with the screen edge, rounded below —
    /// `border-radius: 0 0 28px 28px`.
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: PanelMetrics.bottomRadius,
            bottomTrailingRadius: PanelMetrics.bottomRadius,
            topTrailingRadius: 0
        )
    }

    var body: some View {
        card
            // The whole illusion: height 0 → full, top-aligned, clipped.
            .frame(
                width: PanelMetrics.width,
                height: state.isVisible ? PanelMetrics.height : 0,
                alignment: .top
            )
            .clipShape(shape)
            .offset(y: state.isVisible ? 0 : -5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: state.isVisible) { _, visible in
                searchFocused = visible && state.mode == .clips
            }
    }

    private var card: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(palette.divider).frame(height: 1)
            body_
            Rectangle().fill(palette.divider).frame(height: 1)
            footer
        }
        // Keeps its full size while the clip window grows over it.
        .frame(width: PanelMetrics.width, height: PanelMetrics.height, alignment: .top)
        .background(palette.background)
        // Content settles in just behind the unfurl, slightly faster.
        .opacity(state.isVisible ? 1 : 0)
        .offset(y: state.isVisible ? 0 : -6)
        .animation(Motion.content.delay(state.isVisible ? 0.10 : 0), value: state.isVisible)
        .overlay(alignment: .bottom) { toast }
        // Recede while a system dialog is in front, the way a modal sheet dims its parent.
        .blur(radius: state.isPresentingSheet ? 4 : 0)
        .overlay {
            Rectangle()
                .fill(.black.opacity(state.isPresentingSheet ? 0.35 : 0))
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.2), value: state.isPresentingSheet)
        .environment(\.palette, palette)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            tabBar
            Spacer(minLength: 0)
            iconButton("xmark", help: "Close", action: onClose)
        }
        .padding(.horizontal, 14)
        .frame(height: PanelMetrics.headerHeight)
    }

    private var tabBar: some View {
        HStack(spacing: 3) {
            tab(.clips, symbol: "doc.on.clipboard", help: "Clipboard")
            tab(.timer, symbol: "timer", help: "Focus")
            tab(.todo, symbol: "checklist", help: "To-do")
            tab(.notes, symbol: "note.text", help: "Notes")
            tab(.shelf, symbol: "tray.full", help: "File shelf")
            tab(.game, symbol: "gamecontroller", help: "2048")
            tabItem(.chat, help: "Ask Claude") {
                ClaudeMark(size: 14)
            }
            tab(.system, symbol: "speedometer", help: "System")
            tab(.settings, symbol: "gearshape", help: "Settings")
        }
        .padding(4)
        .background(Capsule().fill(palette.fill))
    }

    private func tab(_ mode: PanelMode, symbol: String, help: String) -> some View {
        tabItem(mode, help: help) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(state.mode == mode ? palette.background : palette.muted)
        }
    }

    private func tabItem<Icon: View>(
        _ mode: PanelMode,
        help: String,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        let selected = state.mode == mode
        return Button {
            go(mode)
        } label: {
            icon()
                .frame(width: 38, height: 28)
                .background(Capsule().fill(selected ? palette.contrast : .clear))
                // Without this the unselected tabs only take clicks on the glyph itself.
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var searchRow: some View {
        searchField
            .padding(.horizontal, 16)
            .frame(height: PanelMetrics.searchRowHeight)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.faint)

            TextField("Search", text: $store.query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.text)
                .tint(palette.contrast)
                .focused($searchFocused)
                .onSubmit { activateSelection() }
                .onChange(of: store.query) { _, _ in state.selectedIndex = 0 }

            if !store.query.isEmpty {
                Button {
                    store.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.faint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(palette.fill, in: Capsule())
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.muted)
                .frame(width: 30, height: 30)
                .background(palette.fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Body

    @ViewBuilder
    private var body_: some View {
        switch state.mode {
        case .clips:
            VStack(spacing: 0) {
                searchRow
                listArea
            }
            .transition(.opacity)
        case .todo:
            TodoView(store: TodoStore.shared)
                .frame(height: PanelMetrics.listHeight)
                .transition(.opacity)
        case .notes:
            NotesView(store: NoteStore.shared)
                .frame(height: PanelMetrics.listHeight)
                .transition(.opacity)
        case .shelf:
            ShelfView(store: ShelfStore.shared, state: state)
                .frame(height: PanelMetrics.listHeight)
                .transition(.opacity)
        case .game:
            GamesView(state: GamesState.shared)
                .frame(height: PanelMetrics.listHeight)
                .transition(.opacity)
        case .chat:
            ChatView(session: ChatSession.shared) { go(.settings) }
                .frame(height: PanelMetrics.listHeight)
                .transition(.opacity)
        case .timer:
            TimerView(timer: PomodoroTimer.shared, settings: settings)
                .frame(height: PanelMetrics.listHeight)
                .transition(.opacity)
        case .system:
            SystemView(monitor: SystemMonitor.shared)
                .frame(height: PanelMetrics.listHeight)
                .transition(.opacity)
        case .settings:
            SettingsPane(settings: settings, store: store, state: state)
                .frame(height: PanelMetrics.listHeight)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var listArea: some View {
        if store.visibleItems.isEmpty {
            emptyState
                .frame(height: PanelMetrics.clipsListHeight)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.visibleItems.enumerated()), id: \.element.id) { index, item in
                            ClipRow(
                                item: item,
                                isSelected: index == state.selectedIndex,
                                thumbnail: item.kind == .image ? store.image(for: item) : nil,
                                onOpen: { onActivate(item) },
                                onPin: { store.togglePin(item) },
                                onDelete: { store.delete(item) },
                                onAsk: { askClaude(about: item) }
                            )
                            .id(item.id)
                            .onHover { hovering in
                                guard hovering else { return }
                                state.selectionFromKeyboard = false
                                state.selectedIndex = index
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
                .frame(height: PanelMetrics.clipsListHeight)
                .onChange(of: state.selectedIndex) { _, index in
                    // Only the arrow keys may move the list. Mouse scrolling stays
                    // entirely under the user's control.
                    guard state.selectionFromKeyboard else { return }
                    let items = store.visibleItems
                    guard items.indices.contains(index) else { return }
                    // No anchor: scrolls the least amount needed to reveal the row,
                    // instead of yanking it to the centre.
                    proxy.scrollTo(items[index].id)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 21, weight: .light))
                .foregroundStyle(palette.faint)
            Text(store.query.isEmpty ? "Nothing copied yet" : "No clips match \u{201C}\(store.query)\u{201D}")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            switch state.mode {
            case .clips:
                Text("Return to paste \u{00B7} \u{2318}P pin \u{00B7} \u{2318}\u{232B} delete")
                Spacer(minLength: 0)
                Text("\(store.visibleItems.count) of \(store.items.count)")
            case .timer:
                Text("Space to start or pause \u{00B7} Esc for clips")
                Spacer(minLength: 0)
            case .todo:
                Text("Return to add \u{00B7} click to tick off")
                Spacer(minLength: 0)
                Text("\(TodoStore.shared.openCount) open")
            case .notes:
                Text("Click a note to edit \u{00B7} saves as you type")
                Spacer(minLength: 0)
                Text("\(NoteStore.shared.notes.count)")
            case .shelf:
                Text("Click to open \u{00B7} drag out to use \u{00B7} add with the button")
                Spacer(minLength: 0)
                Text("\(ShelfStore.shared.items.count) parked")
            case .game:
                Text(gameHint)
                Spacer(minLength: 0)
            case .chat:
                Text("Return to send \u{00B7} streams live \u{00B7} Esc for clips")
                Spacer(minLength: 0)
                Text(ClaudeClient.model)
            case .system:
                Text("Live vitals \u{00B7} sampled every 1.5s")
                Spacer(minLength: 0)
            case .settings:
                Text("Changes save as you make them")
                Spacer(minLength: 0)
            }
            Text(settings.shortcut.display)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(palette.fill, in: Capsule())
        }
        .font(.system(size: 10))
        .foregroundStyle(palette.faint)
        .padding(.horizontal, 16)
        .frame(height: PanelMetrics.footerHeight)
    }

    @ViewBuilder
    private var toast: some View {
        if let toast = state.toast {
            Text(toast)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.background)
                .padding(.horizontal, 13)
                .padding(.vertical, 5)
                .background(palette.contrast, in: Capsule())
                .padding(.bottom, 36)
                .transition(.opacity)
        }
    }

    // MARK: - Actions

    /// Hands a clip to the chat page as a starting prompt.
    private func askClaude(about item: ClipItem) {
        ChatSession.shared.prefill = item.text
        go(.chat)
    }

    private var gameHint: String {
        switch GamesState.shared.selected {
        case .twenty48: return "Arrow keys or WASD \u{00B7} Space for a new game"
        case .minesweeper: return "Click to reveal \u{00B7} right-click to flag \u{00B7} Space to restart"
        case .snake: return "Arrow keys or WASD \u{00B7} Space to pause"
        case .memory: return "Click a card \u{00B7} Space for a new board"
        }
    }

    private func go(_ mode: PanelMode) {
        searchFocused = false
        withAnimation(Motion.swap) { state.mode = mode }
        if mode == .clips { searchFocused = true }
    }

    private func activateSelection() {
        let items = store.visibleItems
        guard items.indices.contains(state.selectedIndex) else { return }
        onActivate(items[state.selectedIndex])
    }
}

// MARK: - Row

struct ClipRow: View {
    let item: ClipItem
    let isSelected: Bool
    let thumbnail: NSImage?
    var onOpen: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void
    var onAsk: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                badge
                Text(item.preview)
                    .font(.system(size: 12.5, design: item.kind == .url ? .monospaced : .default))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 11)
            .frame(height: PanelMetrics.rowHeight - 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? palette.selection : .clear)
            )
            .padding(.horizontal, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Ask Claude", action: onAsk)
            Button(item.pinned ? "Unpin" : "Pin", action: onPin)
            Button("Delete", action: onDelete)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 26, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Image(systemName: item.kind.symbol)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(isSelected ? palette.text : palette.muted)
                .frame(width: 26, height: 22)
                .background(palette.fill, in: RoundedRectangle(cornerRadius: 5))
        }
    }

    private var trailing: some View {
        HStack(spacing: 7) {
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow.opacity(0.8))
            }
            Text(item.sourceAppName ?? "")
                .lineLimit(1)
            Text(item.relativeTime)
                .monospacedDigit()
        }
        .font(.system(size: 10))
        .foregroundStyle(isSelected ? palette.muted : palette.faint)
    }
}
