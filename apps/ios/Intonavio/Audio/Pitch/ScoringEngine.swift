import Foundation

/// Evaluates detected pitch against reference, accumulating session and per-phrase statistics.
@Observable
final class ScoringEngine {
    private(set) var pitchLog: [PitchLogEntry] = []
    private(set) var overallScore: Double = 0
    private(set) var currentAccuracy: PitchAccuracy = .unvoiced
    var transposeSemitones: Int = 0

    // Phrase scoring
    private(set) var phraseScores: [Int: PhraseScoreResult] = [:]
    private(set) var currentPhraseIndex: Int?
    var onPhraseCompleted: ((PhraseScoreResult) -> Void)?

    private var totalPoints: Double = 0
    private var voicedReferenceFrames: Int = 0

    // Per-phrase accumulators
    private var phraseTotalPoints: [Int: Double] = [:]
    private var phraseVoicedFrames: [Int: Int] = [:]

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

        trackPhraseTransition(at: playbackTime)

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

        totalPoints += accuracy.points()
        accumulatePhrasePoints(accuracy.points())

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
        finalizeCurrentPhrase()
        pitchLog = []
        overallScore = 0
        totalPoints = 0
        voicedReferenceFrames = 0
        currentAccuracy = .unvoiced
        phraseScores = [:]
        currentPhraseIndex = nil
        phraseTotalPoints = [:]
        phraseVoicedFrames = [:]
    }

    /// Finalize any in-progress phrase (e.g., before loop reset).
    func finalizeCurrentPhrase() {
        guard let index = currentPhraseIndex else { return }
        let result = buildPhraseResult(for: index)
        phraseScores[index] = result
        onPhraseCompleted?(result)
        currentPhraseIndex = nil
    }
}

// MARK: - Phrase Tracking

private extension ScoringEngine {
    func trackPhraseTransition(at playbackTime: Double) {
        let phrase = referenceStore.phrase(at: playbackTime)
        let newIndex = phrase?.index

        if newIndex != currentPhraseIndex {
            // Previous phrase ended
            if let oldIndex = currentPhraseIndex {
                let result = buildPhraseResult(for: oldIndex)
                phraseScores[oldIndex] = result
                onPhraseCompleted?(result)
            }
            currentPhraseIndex = newIndex
        }
    }

    func accumulatePhrasePoints(_ points: Double) {
        guard let index = currentPhraseIndex else { return }
        phraseTotalPoints[index, default: 0] += points
        phraseVoicedFrames[index, default: 0] += 1
    }

    func buildPhraseResult(for index: Int) -> PhraseScoreResult {
        let total = phraseTotalPoints[index, default: 0]
        let frames = phraseVoicedFrames[index, default: 0]
        let score = frames > 0 ? total / Double(frames) : 0

        let phrase = referenceStore.phrases.first { $0.index == index }

        return PhraseScoreResult(
            phraseIndex: index,
            score: score,
            startTime: phrase?.startTime ?? 0,
            endTime: phrase?.endTime ?? 0
        )
    }
}
