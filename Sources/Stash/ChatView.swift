import SwiftUI
import Observation

/// One running conversation. Kept app-wide so switching tabs doesn't lose it.
@Observable
@MainActor
final class ChatSession {
    static let shared = ChatSession()

    var messages: [ChatMessage] = []
    var isStreaming = false
    var errorText: String?
    /// Text dropped in from elsewhere — e.g. "Ask Claude" on a clip.
    var prefill: String?

    @ObservationIgnored private var task: Task<Void, Never>?

    private init() {}

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        errorText = nil
        messages.append(ChatMessage(role: .user, text: trimmed))
        messages.append(ChatMessage(role: .assistant, text: ""))
        isStreaming = true

        // The empty assistant message is the one being filled in.
        let history = Array(messages.dropLast())

        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await ClaudeClient.shared.send(history: history) { delta in
                    guard let index = self.messages.indices.last else { return }
                    self.messages[index].text += delta
                }
            } catch is CancellationError {
                // Stopped on purpose — keep whatever streamed so far.
            } catch {
                self.errorText = error.localizedDescription
                if self.messages.last?.text.isEmpty == true {
                    self.messages.removeLast()
                }
            }
            self.isStreaming = false
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isStreaming = false
    }

    func clear() {
        stop()
        messages.removeAll()
        errorText = nil
    }
}

struct ChatView: View {
    @Bindable var session: ChatSession
    var onOpenSettings: () -> Void

    @Environment(\.palette) private var palette
    @FocusState private var inputFocused: Bool
    @State private var draft = ""

    private var hasKey: Bool { ClaudeClient.shared.hasKey }

    var body: some View {
        VStack(spacing: 0) {
            if !hasKey {
                needsKey
            } else {
                transcript
                if let error = session.errorText {
                    errorBar(error)
                }
                inputRow
            }
        }
        .onAppear {
            if let prefill = session.prefill {
                draft = prefill
                session.prefill = nil
            }
            inputFocused = hasKey
        }
    }

    // MARK: - No key yet

    private var needsKey: some View {
        VStack(spacing: 10) {
            ClaudeMark(size: 26)
            Text("Add your Anthropic API key to chat")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
            Button(action: onOpenSettings) {
                Text("Open Settings")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.background)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 14)
                    .background(Capsule().fill(palette.contrast))
            }
            .buttonStyle(.plain)
            Text("Get one at console.anthropic.com")
                .font(.system(size: 9.5))
                .foregroundStyle(palette.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if session.messages.isEmpty {
                        VStack(spacing: 10) {
                            ClaudeMark(size: 24)
                            Text("Ask anything \u{2014} or hit \u{201C}Ask Claude\u{201D} on any clip.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(palette.faint)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 52)
                    }
                    ForEach(session.messages) { message in
                        bubble(message).id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: session.messages.last?.text) { _, _ in
                guard let last = session.messages.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.text)
                    .textSelection(.enabled)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 11)
                    .background(RoundedRectangle(cornerRadius: 11).fill(palette.selection))
            }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Text(message.text.isEmpty ? "\u{2026}" : message.text)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !message.text.isEmpty && !session.isStreaming {
                    Button {
                        Paster.copyText(message.text)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 9.5))
                            .foregroundStyle(palette.faint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func errorBar(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(palette.muted)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.10))
    }

    // MARK: - Input

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Message Claude", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.text)
                .tint(palette.contrast)
                .lineLimit(1...3)
                .focused($inputFocused)
                .onSubmit(submit)

            if session.isStreaming {
                circleButton("stop.fill") { session.stop() }
            } else {
                circleButton("arrow.up", filled: !draft.isEmpty, action: submit)
            }

            if !session.messages.isEmpty {
                circleButton("trash") { session.clear() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.background)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    private func circleButton(
        _ symbol: String,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(filled ? palette.background : palette.muted)
                .frame(width: 24, height: 24)
                .background(Circle().fill(filled ? palette.contrast : palette.fill))
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        session.send(draft)
        draft = ""
    }
}
