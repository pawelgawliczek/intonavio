import SwiftUI

/// Container for the piano roll: mode selector, canvas, current note display.
struct PianoRollView: View {
    @Binding var mode: VisualizationMode
    let referenceFrames: ArraySlice<ReferencePitchFrame>
    let hopDuration: Double
    let detectedPoints: [DetectedPitchPoint]
    let currentTime: Double
    let currentNoteName: String?
    let centsDeviation: Float
    let accuracy: PitchAccuracy
    let score: Double
    let isPitchReady: Bool
    let midiMin: Float
    let midiMax: Float
    let transposeSemitones: Int
    var phraseIndex: Int?
    var totalPhrases: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if isPitchReady {
                CurrentNoteView(
                    noteName: currentNoteName,
                    centsDeviation: centsDeviation,
                    accuracy: accuracy,
                    score: score,
                    phraseIndex: phraseIndex,
                    totalPhrases: totalPhrases
                )

                PianoRollCanvas(
                    mode: mode,
                    referenceFrames: referenceFrames,
                    hopDuration: hopDuration,
                    detectedPoints: detectedPoints,
                    currentTime: currentTime,
                    midiMin: midiMin,
                    midiMax: midiMax,
                    transposeSemitones: transposeSemitones
                )
            } else {
                pitchUnavailable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformGroupedBackground)
    }
}

// MARK: - Unavailable State

private extension PianoRollView {
    var pitchUnavailable: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "waveform.slash")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Pitch analysis not available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Switch to instrumental mode with a processed song")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}

#Preview("With Data") {
    PianoRollView(
        mode: .constant(.zonesLine),
        referenceFrames: [][...],
        hopDuration: 0.0058,
        detectedPoints: [],
        currentTime: 10,
        currentNoteName: "C4",
        centsDeviation: 5,
        accuracy: .excellent,
        score: 85,
        isPitchReady: true,
        midiMin: 55,
        midiMax: 75,
        transposeSemitones: 0
    )
    .frame(height: 200)
}

#Preview("Unavailable") {
    PianoRollView(
        mode: .constant(.zonesLine),
        referenceFrames: [][...],
        hopDuration: 0,
        detectedPoints: [],
        currentTime: 0,
        currentNoteName: nil,
        centsDeviation: 0,
        accuracy: .unvoiced,
        score: 0,
        isPitchReady: false,
        midiMin: 48,
        midiMax: 72,
        transposeSemitones: 0
    )
    .frame(height: 200)
}
