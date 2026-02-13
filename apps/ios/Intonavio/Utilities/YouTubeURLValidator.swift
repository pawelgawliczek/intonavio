import Foundation

/// Validates YouTube URLs matching the same regex as the backend.
enum YouTubeURLValidator {
    // swiftlint:disable:next line_length
    private static let pattern = #"^https?://(www\.)?(youtube\.com/(watch\?.*v=|shorts/|embed/)|youtu\.be/|m\.youtube\.com/(watch\?.*v=|shorts/))[a-zA-Z0-9_-]{11}"#

    static func isValid(_ urlString: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(urlString.startIndex..., in: urlString)
        return regex.firstMatch(in: urlString, range: range) != nil
    }

    static func extractVideoId(_ urlString: String) -> String? {
        guard isValid(urlString) else { return nil }

        if let components = URLComponents(string: urlString),
           let queryV = components.queryItems?.first(where: { $0.name == "v" })?.value,
           queryV.count == 11 {
            return queryV
        }

        let patterns: [String] = [
            #"youtu\.be/([a-zA-Z0-9_-]{11})"#,
            #"youtube\.com/embed/([a-zA-Z0-9_-]{11})"#,
            #"youtube\.com/shorts/([a-zA-Z0-9_-]{11})"#
        ]

        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat),
               let match = regex.firstMatch(
                   in: urlString,
                   range: NSRange(urlString.startIndex..., in: urlString)
               ),
               let range = Range(match.range(at: 1), in: urlString) {
                return String(urlString[range])
            }
        }

        return nil
    }
}
