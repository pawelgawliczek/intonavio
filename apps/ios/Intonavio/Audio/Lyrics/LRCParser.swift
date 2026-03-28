import Foundation

/// Parses LRC (synced lyrics) format into an array of `LyricLine`.
enum LRCParser {
    // swiftlint:disable:next force_try - pattern is a compile-time constant
    private static let regex = try! NSRegularExpression(
        pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.+)"#
    )

    /// Parse LRC content string into sorted lyric lines.
    /// Skips metadata tags, blank lines, and lines without text.
    static func parse(_ content: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        for rawLine in content.components(separatedBy: .newlines) {
            let range = NSRange(rawLine.startIndex..., in: rawLine)
            guard let match = regex.firstMatch(in: rawLine, range: range),
                  match.numberOfRanges == 5 else {
                continue
            }

            guard let minutesRange = Range(match.range(at: 1), in: rawLine),
                  let secondsRange = Range(match.range(at: 2), in: rawLine),
                  let subsecRange = Range(match.range(at: 3), in: rawLine),
                  let textRange = Range(match.range(at: 4), in: rawLine) else {
                continue
            }

            let minutes = Double(rawLine[minutesRange]) ?? 0
            let seconds = Double(rawLine[secondsRange]) ?? 0
            let subsecStr = String(rawLine[subsecRange])
            let time = minutes * 60.0 + seconds + parseSubseconds(subsecStr)

            let text = String(rawLine[textRange]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            lines.append(LyricLine(time: time, text: text))
        }

        return lines.sorted { $0.time < $1.time }
    }

    private static func parseSubseconds(_ value: String) -> Double {
        guard let number = Double(value) else { return 0 }
        // "xx" = centiseconds (divide by 100), "xxx" = milliseconds (divide by 1000)
        return value.count <= 2 ? number / 100.0 : number / 1000.0
    }
}
