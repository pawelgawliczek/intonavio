import Foundation

/// Audio playback mode determining which audio sources are active.
enum AudioMode: String, CaseIterable, Sendable {
    case original
    case vocalsOnly
    case instrumental

    /// Whether YouTube audio should be muted in this mode.
    var isYouTubeMuted: Bool {
        self != .original
    }

    /// Whether stem playback is active in this mode.
    var isStemActive: Bool {
        self != .original
    }

    /// Whether vocals stem should play in this mode.
    var hasVocals: Bool {
        self == .vocalsOnly
    }

    /// Whether non-vocal stems should play in this mode.
    var hasInstrumental: Bool {
        self == .instrumental
    }
}
