import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user, assistant
    }

    let id = UUID()
    var role: Role
    var text: String
}

enum ClaudeError: LocalizedError {
    case missingKey
    case http(Int, String)
    case refused(String?)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add your Anthropic API key in Settings."
        case .http(401, _):
            return "That API key was rejected (401). Check it in Settings."
        case .http(429, _):
            return "Rate limited (429). Try again in a moment."
        case .http(let code, let body):
            return "API error \(code): \(body)"
        case .refused(let category):
            if let category {
                return "Claude declined this request (\(category))."
            }
            return "Claude declined this request."
        }
    }
}

/// Talks to the Messages API over raw HTTP — Anthropic ships no Swift SDK.
@MainActor
final class ClaudeClient {
    static let shared = ClaudeClient()

    static let keychainAccount = "anthropic-api-key"
    static let model = "claude-opus-5"

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private init() {}

    /// Keychain first. An exported shell variable is only visible when the app was
    /// launched from a terminal, so it's a fallback rather than the main path.
    var apiKey: String? {
        if let stored = Keychain.get(account: Self.keychainAccount), !stored.isEmpty {
            return stored
        }
        let environment = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        return (environment?.isEmpty == false) ? environment : nil
    }

    var hasKey: Bool { apiKey != nil }

    func store(key: String) {
        Keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), account: Self.keychainAccount)
    }

    func clearKey() {
        Keychain.delete(account: Self.keychainAccount)
    }

    private let system = """
        You are a helpful assistant embedded in a small macOS clipboard utility. \
        Answers render in a narrow panel, so keep them short and concrete. \
        Prefer a direct answer over preamble. Use short code blocks where they help.
        """

    /// Streams the reply, handing back each text delta as it arrives.
    func send(
        history: [ChatMessage],
        onDelta: @escaping (String) -> Void
    ) async throws {
        guard let apiKey else { throw ClaudeError.missingKey }

        let payload: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16_000,
            "stream": true,
            "system": system,
            // Opus 5's classifiers can decline a request; this re-runs it server-side
            // on Anthropic's recommended substitute instead of handing back a refusal.
            "fallbacks": "default",
            "messages": history.map { ["role": $0.role.rawValue, "content": $0.text] }
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 120

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 800 { break }
            }
            throw ClaudeError.http(http.statusCode, body)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let json = String(line.dropFirst(6))

            guard let data = json.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String
            else { continue }

            switch type {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    onDelta(text)
                }

            case "message_delta":
                // Check the stop reason before trusting the text we collected.
                if let delta = event["delta"] as? [String: Any],
                   delta["stop_reason"] as? String == "refusal" {
                    let details = delta["stop_details"] as? [String: Any]
                    throw ClaudeError.refused(details?["category"] as? String)
                }

            case "error":
                let error = event["error"] as? [String: Any]
                throw ClaudeError.http(500, error?["message"] as? String ?? "stream error")

            default:
                break
            }
        }
    }
}
