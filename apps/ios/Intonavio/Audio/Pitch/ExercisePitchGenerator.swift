import Foundation

/// Generates ReferencePitchData from exercise note definitions + tempo.
/// Handles sustained notes, vibrato modulation, and rests.
enum ExercisePitchGenerator {
    private static let sampleRate = Int(PitchConstants.sampleRate)
    private static let hopLength = PitchConstants.hopSize

    /// Generate reference pitch data for an exercise at a given tempo.
    static func generate(
        notes: [ExerciseNote],
        tempo: Int
    ) -> ReferencePitchData {
        let hopDuration = Double(hopLength) / Double(sampleRate)
        let beatDuration = 60.0 / Double(tempo)
        var frames: [ReferencePitchFrame] = []
        var currentTime: Double = 0

        for note in notes {
            let noteDuration = note.durationBeats * beatDuration
            let frameCount = Int(noteDuration / hopDuration)

            for frameIndex in 0..<frameCount {
                let time = currentTime + Double(frameIndex) * hopDuration

                if note.isRest {
                    frames.append(ReferencePitchFrame(
                        time: time,
                        frequency: nil,
                        isVoiced: false,
                        midiNote: nil,
                        rms: nil
                    ))
                    continue
                }

                let baseFrequency = Double(
                    NoteMapper.midiToFrequency(Float(note.midiNote))
                )

                let frequency: Double
                if note.hasVibrato {
                    frequency = applyVibrato(
                        baseFrequency: baseFrequency,
                        time: time,
                        noteStartTime: currentTime
                    )
                } else {
                    frequency = baseFrequency
                }

                frames.append(ReferencePitchFrame(
                    time: time,
                    frequency: frequency,
                    isVoiced: true,
                    midiNote: Double(note.midiNote),
                    rms: nil
                ))
            }

            currentTime += noteDuration
        }

        return ReferencePitchData(
            songId: nil,
            sampleRate: sampleRate,
            hopSize: hopLength,
            frameCount: frames.count,
            hopDuration: hopDuration,
            frames: frames,
            phrases: []
        )
    }

    /// Apply vibrato modulation: ±30 cents at ~5.5Hz oscillation.
    private static func applyVibrato(
        baseFrequency: Double,
        time: Double,
        noteStartTime: Double
    ) -> Double {
        let vibratoRate = 5.5 // Hz
        let vibratoDepthCents = 30.0
        let elapsed = time - noteStartTime

        // Ramp in vibrato over first 0.3 seconds
        let ramp = min(1.0, elapsed / 0.3)
        let modulation = sin(2.0 * .pi * vibratoRate * elapsed)
        let centsOffset = vibratoDepthCents * modulation * ramp

        return baseFrequency * pow(2.0, centsOffset / 1200.0)
    }
}
