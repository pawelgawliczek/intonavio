import Foundation

/// A single frame of reference pitch data matching pYIN worker output.
/// Worker JSON keys: `t`, `hz`, `midi`, `voiced`.
struct ReferencePitchFrame: Codable, Sendable {
    let time: Double
    let frequency: Double?
    let isVoiced: Bool
    let midiNote: Double?

    enum CodingKeys: String, CodingKey {
        case time = "t"
        case frequency = "hz"
        case isVoiced = "voiced"
        case midiNote = "midi"
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
