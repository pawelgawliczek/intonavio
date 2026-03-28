import Foundation

/// Controls the top panel in practice view: lyrics panel or video.
enum PracticeLayoutMode: String, CaseIterable, Sendable {
    case lyrics   // Lyrics panel + piano roll (default)
    case video    // YouTube video + piano roll

    var topFraction: CGFloat {
        switch self {
        case .lyrics: return 0.35
        case .video: return 0.40
        }
    }
}
