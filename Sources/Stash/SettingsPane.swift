import AppKit
import SwiftUI
import ServiceManagement

/// Click to record, then hold ⌘ / ⌥ / ⌃ (any combination) and press one more key.
/// That combination becomes the global shortcut straight away.
struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut
    @Bindable var state: PanelState

    @State private var monitor: Any?
    @State private var hint: String?

    @Environment(\.palette) private var palette

    private var isRecording: Bool { monitor != nil }

    var body: some View {
        HStack(spacing: 8) {
            if let hint {
                Text(hint)
                    .font(.system(size: 9.5))
                    .foregroundStyle(palette.faint)
            }

            Button {
                isRecording ? stop() : start()
            } label: {
                Text(isRecording ? "Press keys\u{2026}" : shortcut.display)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(isRecording ? palette.background : palette.text)
                    .frame(minWidth: 62)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule().fill(isRecording ? palette.contrast : palette.fill)
                    )
            }
            .buttonStyle(.plain)
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        hint = "\u{2318} \u{2325} \u{2303} + key"
        state.isRecordingShortcut = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // esc cancels
                stop()
                return nil
            }

            let candidate = KeyShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: KeyShortcut.carbonModifiers(from: event.modifierFlags)
            )

            // A bare key would hijack typing everywhere, so insist on a real modifier.
            guard candidate.isValid else {
                hint = "Hold \u{2318}, \u{2325} or \u{2303}"
                return nil
            }

            shortcut = candidate
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        state.isRecordingShortcut = false
        hint = nil
    }
}

/// The settings page, shown inside the panel rather than in a separate window.
struct SettingsPane: View {
    @Bindable var settings: Settings
    @Bindable var store: ClipboardStore
    @Bindable var state: PanelState

    @Environment(\.palette) private var palette

    @State private var apiKeyDraft = ""
    @State private var hasAPIKey = ClaudeClient.shared.hasKey
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasAccessibility = Paster.hasAccessibilityPermission

    private let limits = [100, 250, 500, 1000, 2500]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                row("Theme") {
                    ThemePicker(theme: $settings.theme)
                }

                row("Shortcut") {
                    ShortcutRecorder(shortcut: $settings.shortcut, state: state)
                }

                row(
                    "Paste automatically",
                    note: settings.autoPaste && !hasAccessibility
                        ? "Needs Accessibility \u{2014} otherwise it just copies"
                        : nil
                ) {
                    HStack(spacing: 8) {
                        if settings.autoPaste && !hasAccessibility {
                            Button("Grant\u{2026}") { Paster.requestAccessibilityPermission() }
                                .buttonStyle(.plain)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(palette.text)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                                .background(Capsule().fill(palette.fill))
                        }
                        Toggle("", isOn: $settings.autoPaste)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                }

                row(
                    "Anthropic API key",
                    note: hasAPIKey ? "Saved in your Keychain" : "Get one at console.anthropic.com"
                ) {
                    HStack(spacing: 6) {
                        if hasAPIKey {
                            Text("\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}")
                                .font(.system(size: 11))
                                .foregroundStyle(palette.muted)
                            pill("Remove") {
                                ClaudeClient.shared.clearKey()
                                hasAPIKey = false
                            }
                        } else {
                            SecureField("sk-ant-\u{2026}", text: $apiKeyDraft)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(palette.text)
                                .frame(width: 150)
                                .onSubmit(saveKey)
                            pill("Save", action: saveKey)
                        }
                    }
                }

                row("Focus length") {
                    HStack(spacing: 8) {
                        stepButton("minus") {
                            settings.timerMinutes = max(1, settings.timerMinutes - 5)
                        }
                        Text("\(settings.timerMinutes) min")
                            .font(.system(size: 11.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(palette.text)
                            .frame(width: 46)
                        stepButton("plus") {
                            settings.timerMinutes = min(180, settings.timerMinutes + 5)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(palette.fill))
                }

                row("Timer under the notch", note: "Small countdown while a session runs") {
                    Toggle("", isOn: $settings.showTimerHUD)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }

                row("Completion sound", note: "Pick one to hear it") {
                    Menu {
                        ForEach(CompletionSound.allCases) { sound in
                            Button(sound.label) {
                                settings.completionSound = sound
                                sound.play()
                            }
                        }
                    } label: {
                        Text(settings.completionSound.label)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(palette.text)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                row("Pause capturing") {
                    Toggle("", isOn: $settings.capturePaused)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }

                row("Launch at login") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .onChange(of: launchAtLogin) { _, enabled in
                            setLaunchAtLogin(enabled)
                        }
                }

                row("Keep up to", note: "\(store.items.count) stored now") {
                    Menu {
                        ForEach(limits, id: \.self) { limit in
                            Button("\(limit) clips") { settings.historyLimit = limit }
                        }
                    } label: {
                        Text("\(settings.historyLimit)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(palette.text)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                row("Clear history") {
                    HStack(spacing: 6) {
                        pill("Unpinned") { store.clearUnpinned() }
                        pill("Everything") { store.clearAll() }
                    }
                }

                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)

                row("Quit Stash", note: "History stays saved on disk") {
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Text("Quit")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.95))
                            .padding(.vertical, 3.5)
                            .padding(.horizontal, 11)
                            .background(Capsule().fill(Color.red.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            hasAccessibility = Paster.hasAccessibilityPermission
            launchAtLogin = SMAppService.mainApp.status == .enabled
            hasAPIKey = ClaudeClient.shared.hasKey
        }
    }

    private func row<Content: View>(
        _ title: String,
        note: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.text)
                if let note {
                    Text(note)
                        .font(.system(size: 9.5))
                        .foregroundStyle(palette.faint)
                }
            }
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(palette.muted)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(palette.muted)
                .padding(.vertical, 3.5)
                .padding(.horizontal, 9)
                .background(Capsule().fill(palette.fill))
        }
        .buttonStyle(.plain)
    }

    private func saveKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ClaudeClient.shared.store(key: trimmed)
        apiKeyDraft = ""
        hasAPIKey = ClaudeClient.shared.hasKey
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Stash: launch-at-login failed \u{2014} \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// Three-way segmented control for the appearance.
struct ThemePicker: View {
    @Binding var theme: Theme
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Theme.allCases) { option in
                Button {
                    withAnimation(Motion.swap) { theme = option }
                } label: {
                    Text(option.label)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(theme == option ? palette.background : palette.muted)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule().fill(theme == option ? palette.contrast : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(palette.fill))
    }
}
