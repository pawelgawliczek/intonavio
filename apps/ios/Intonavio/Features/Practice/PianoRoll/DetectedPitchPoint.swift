import Foundation

/// A single detected pitch point for piano roll rendering.
struct DetectedPitchPoint: Sendable {
    let time: Double
    let midi: Float
    let accuracy: PitchAccuracy
    let cents: Float
}
