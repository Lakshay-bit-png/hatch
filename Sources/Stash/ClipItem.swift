import AppKit

/// One thing the user copied.
struct ClipItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text, url, image, file

        var symbol: String {
            switch self {
            case .text: return "text.alignleft"
            case .url: return "link"
            case .image: return "photo"
            case .file: return "doc"
            }
        }
    }

    var id: UUID = UUID()
    var kind: Kind
    /// Full text for text/url/file kinds; a caption for images.
    var text: String
    /// Filename inside the images directory, for `.image` items.
    var imageFile: String?
    var sourceAppName: String?
    var sourceBundleID: String?
    var createdAt: Date = Date()
    var pinned: Bool = false

    /// Key used to collapse repeat copies of the same thing.
    var dedupeKey: String {
        switch kind {
        case .image: return "image:\(imageFile ?? id.uuidString)"
        default: return "\(kind.rawValue):\(text)"
        }
    }

    /// Single-line version for the card, with runs of whitespace flattened.
    var preview: String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        return flattened.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : flattened
    }

    var lineCount: Int {
        text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    /// Short human label under each card, e.g. "240 chars · 6 lines".
    var detail: String {
        switch kind {
        case .image:
            return "Image"
        case .file:
            return (text as NSString).lastPathComponent
        case .url:
            return URL(string: text)?.host ?? "Link"
        case .text:
            let chars = text.count
            let lines = lineCount
            return lines > 1 ? "\(chars) chars · \(lines) lines" : "\(chars) chars"
        }
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
