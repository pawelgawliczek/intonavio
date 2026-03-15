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
struct NoteInfo: Sendable {
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
    /// Analysis window size for YIN. Must be > 2 * maxLag.
    static let analysisSize: Int = 2048
    /// Hardware IO buffer — request smallest possible (256).
    static let ioBufferSize: UInt32 = 256
    /// Slide the analysis window every N new samples (~172 readings/sec).
    static let hopSize: Int = 256
    static let sampleRate: Float = 44100.0
    static let confidenceThreshold: Float = 0.85
    static let yinThreshold: Float = 0.10
    static let minFrequency: Float = 80.0
    static let maxFrequency: Float = 1100.0

    /// RMS below this value (~-46 dB) is treated as silence.
    static let rmsNoiseFloor: Float = 0.005

    /// Gain multiplier applied to mic input when using Bluetooth (e.g. AirPods).
    /// Compensates for weaker AirPods mic + VP attenuation (~14 dB combined).
    static let bluetoothMicGain: Float = 5.0
    /// Maximum MIDI jump (semitones) allowed between consecutive detections.
    static let maxMidiJump: Float = 12.0
    /// Time window (seconds) for evaluating MIDI jumps.
    static let jumpTimeWindow: TimeInterval = 0.05

    static var minLag: Int {
        Int(sampleRate / maxFrequency)
    }

    static var maxLag: Int {
        Int(sampleRate / minFrequency)
    }
}
