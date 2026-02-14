import Foundation

/// A single frame of reference pitch data matching pYIN worker output.
/// Worker JSON keys: `t`, `hz`, `midi`, `voiced`, `rms`.
struct ReferencePitchFrame: Codable, Sendable {
    let time: Double
    let frequency: Double?
    let isVoiced: Bool
    let midiNote: Double?
    let rms: Double?

    /// Frames with RMS below this threshold are treated as artifacts from
    /// imperfect stem separation and excluded from rendering/scoring.
    static let rmsThreshold: Double = 0.02

    /// Whether this frame has enough energy to be considered a real vocal signal.
    var isAudible: Bool {
        guard let rms else { return true }
        return rms >= Self.rmsThreshold
    }

    enum CodingKeys: String, CodingKey {
        case time = "t"
        case frequency = "hz"
        case isVoiced = "voiced"
        case midiNote = "midi"
        case rms
    }
}

/// Complete reference pitch data for a song, as produced by the pYIN worker.
/// Worker JSON keys: `songId`, `sampleRate`, `hopSize`, `hopDuration`, `frameCount`, `frames`.
struct ReferencePitchData: Codable, Sendable {
    let songId: String?
    let sampleRate: Int
    let hopSize: Int
    let frameCount: Int
    let hopDuration: Double
    let frames: [ReferencePitchFrame]
}
