import Foundation

/// A single timestamped lyric line parsed from LRC format.
struct LyricLine: Sendable {
    /// Time offset in seconds from song start.
    let time: Double
    /// The lyric text for this line.
    let text: String
}
