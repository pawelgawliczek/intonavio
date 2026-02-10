import Foundation

/// Result of a single pitch detection cycle.
struct PitchResult: Sendable {
    let frequency: Float
    let confidence: Float
    let midiNote: Int
    let noteName: String
    let centsDeviation: Float
    let timestamp: TimeInterval
}

/// Describes a musical note for display purposes.
struct NoteInfo {
    let name: String
    let octave: Int
    let midiNumber: Int

    var fullName: String { "\(name)\(octave)" }
}

/// A single point on the pitch graph.
struct PitchPoint: Sendable {
    let time: TimeInterval
    let frequency: Float
    let confidence: Float
}

/// Constants for pitch detection configuration.
enum PitchConstants {
    /// Analysis window size for YIN. Must be > 2 * maxLag
    /// so halfLen (analysisSize/2) exceeds maxLag (sampleRate/minFreq).
    static let analysisSize: Int = 2048
    /// Hardware IO buffer — request smallest possible (256).
    /// iOS will grant 256 on modern devices (~5.8ms).
    static let ioBufferSize: UInt32 = 256
    /// Slide the analysis window every N new samples.
    /// 256 = ~172 pitch readings/sec at 44.1kHz.
    static let hopSize: Int = 256
    static let sampleRate: Float = 44100.0
    static let confidenceThreshold: Float = 0.8
    static let yinThreshold: Float = 0.10
    static let minFrequency: Float = 80.0
    static let maxFrequency: Float = 1100.0

    static var minLag: Int {
        Int(sampleRate / maxFrequency)
    }

    static var maxLag: Int {
        Int(sampleRate / minFrequency)
    }
}
