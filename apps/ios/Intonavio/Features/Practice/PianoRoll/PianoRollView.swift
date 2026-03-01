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
    let zones: [(halfCents: Float, color: Color)]
    var phraseIndex: Int?
    var totalPhrases: Int = 0

    // Gesture support
    var gestureState: PianoRollGestureState?
    var momentumEngine: PianoRollMomentumEngine?
    var songDuration: Double = 0
    var referenceStore: ReferencePitchStore?
    var playbackTime: Double?
    var onPause: (() -> Void)?
    var onSeek: ((Double) -> Void)?
    var onResume: (() -> Void)?
    var onSetupPhraseLoop: ((Int) -> Void)?

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

                canvasWithGestures
            } else {
                pitchUnavailable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.intonavioBackground)
    }
}

// MARK: - Canvas with Gesture Overlay

private extension PianoRollView {
    @ViewBuilder
    var canvasWithGestures: some View {
        let isBrowsing = gestureState?.isBrowsing ?? false

        if let gs = gestureState,
           let me = momentumEngine,
           let store = referenceStore,
           let pause = onPause,
           let seek = onSeek,
           let resume = onResume,
           let phraseLoop = onSetupPhraseLoop {
            GeometryReader { geometry in
                PianoRollCanvas(
                    mode: mode,
                    referenceFrames: referenceFrames,
                    hopDuration: hopDuration,
                    detectedPoints: detectedPoints,
                    currentTime: currentTime,
                    midiMin: midiMin,
                    midiMax: midiMax,
                    transposeSemitones: transposeSemitones,
                    zones: zones,
                    playbackTime: playbackTime,
                    isBrowsing: isBrowsing
                )
                .overlay {
                    PianoRollGestureOverlay(
                        gestureState: gs,
                        momentumEngine: me,
                        canvasWidth: geometry.size.width,
                        currentTime: currentTime,
                        songDuration: songDuration,
                        referenceStore: store,
                        onPause: pause,
                        onSeek: seek,
                        onResume: resume,
                        onSetupPhraseLoop: phraseLoop
                    )
                }
            }
        } else {
            PianoRollCanvas(
                mode: mode,
                referenceFrames: referenceFrames,
                hopDuration: hopDuration,
                detectedPoints: detectedPoints,
                currentTime: currentTime,
                midiMin: midiMin,
                midiMax: midiMax,
                transposeSemitones: transposeSemitones,
                zones: zones
            )
        }
    }
}

// MARK: - Unavailable State

private extension PianoRollView {
    var pitchUnavailable: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "waveform.slash")
                .font(.title2)
                .foregroundStyle(Color.intonavioIce.opacity(0.5))
            Text("Pitch analysis not available")
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)
            Text("Switch to instrumental mode with a processed song")
                .font(.caption)
                .foregroundStyle(Color.intonavioTextSecondary.opacity(0.7))
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
        transposeSemitones: 0,
        zones: DifficultyLevel.current.zones
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
        transposeSemitones: 0,
        zones: DifficultyLevel.current.zones
    )
    .frame(height: 200)
}
