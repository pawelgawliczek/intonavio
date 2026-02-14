import Foundation

/// Audio playback mode determining which audio sources are active.
enum AudioMode: String, CaseIterable, Sendable {
    case original
    case vocalsOnly
    case instrumental

    /// Whether vocals stem should play.
    var hasVocals: Bool { self == .vocalsOnly }

    /// Whether non-vocal stems should play.
    var hasInstrumental: Bool { self == .instrumental }

    /// Whether the full mix stem should play.
    var hasFull: Bool { self == .original }
}
