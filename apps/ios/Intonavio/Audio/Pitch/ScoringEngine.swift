import Foundation

/// Evaluates detected pitch against reference, accumulating session statistics.
@Observable
final class ScoringEngine {
    private(set) var pitchLog: [PitchLogEntry] = []
    private(set) var overallScore: Double = 0
    private(set) var currentAccuracy: PitchAccuracy = .unvoiced
    var transposeSemitones: Int = 0

    private var totalPoints: Double = 0
    private var voicedReferenceFrames: Int = 0

    private let referenceStore: ReferencePitchStore

    init(referenceStore: ReferencePitchStore) {
        self.referenceStore = referenceStore
    }

    /// Compute the final score as a percentage (0-100).
    var finalScore: Double {
        guard voicedReferenceFrames > 0 else { return 0 }
        return totalPoints / Double(voicedReferenceFrames)
    }

    /// Evaluate a detected pitch result at the current playback time.
    func evaluate(detected: PitchResult?, playbackTime: Double) {
        guard let refFrame = referenceStore.frame(at: playbackTime) else {
            return
        }

        // Skip scoring during rests (unvoiced reference)
        guard refFrame.isVoiced, let refHz = refFrame.frequency else { return }

        let adjustedRefHz = refHz * pow(2.0, Double(transposeSemitones) / 12.0)

        voicedReferenceFrames += 1

        // Singer is silent during a voiced section
        guard let detected else {
            currentAccuracy = .unvoiced
            pitchLog.append(PitchLogEntry(
                time: playbackTime,
                detectedHz: nil,
                referenceHz: adjustedRefHz,
                cents: nil
            ))
            return
        }

        let cents = NoteMapper.centsBetween(
            detected: detected.frequency,
            reference: Float(adjustedRefHz)
        )
        let accuracy = PitchAccuracy.classify(cents: cents)
        currentAccuracy = accuracy

        totalPoints += accuracy.points

        overallScore = finalScore

        pitchLog.append(PitchLogEntry(
            time: playbackTime,
            detectedHz: Double(detected.frequency),
            referenceHz: adjustedRefHz,
            cents: Double(cents)
        ))
    }

    /// Reset all accumulated scoring state.
    func reset() {
        pitchLog = []
        overallScore = 0
        totalPoints = 0
        voicedReferenceFrames = 0
        currentAccuracy = .unvoiced
    }
}
