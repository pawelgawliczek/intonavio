import Foundation

/// Controls the video/pitch split ratio in practice view.
enum PracticeLayoutMode: String, CaseIterable, Sendable {
    case lyricsFocused  // 65% video, 35% pitch
    case pitchFocused   // 25% video, 75% pitch

    var videoFraction: CGFloat {
        switch self {
        case .lyricsFocused: return 0.65
        case .pitchFocused: return 0.25
        }
    }
}
