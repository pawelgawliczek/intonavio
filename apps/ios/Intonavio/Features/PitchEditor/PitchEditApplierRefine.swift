import Foundation

/// Refine algorithm — uses user-edited frames as anchors to fix octave errors
/// and voicing in the raw base frames while preserving fine-grained pitch.
extension PitchEditApplier {

    static func applyRefine(
        _ frames: inout [ReferencePitchFrame],
        lo: Int,
        hi: Int,
        base: [ReferencePitchFrame]
    ) {
        for i in lo..<hi where i < base.count {
            let anchor = frames[i]
            let raw = base[i]
            frames[i] = refinedFrame(raw: raw, anchor: anchor)
        }
    }

    static func refinedFrame(
        raw: ReferencePitchFrame,
        anchor: ReferencePitchFrame
    ) -> ReferencePitchFrame {
        let anchorVisible = isVisible(anchor)
        let rawVoiced = raw.isVoiced && raw.frequency != nil

        // Both silent → keep raw
        if !anchorVisible && !rawVoiced { return raw }

        // Anchor muted but raw voiced → user wants silence
        if !anchorVisible {
            return ReferencePitchFrame(
                time: raw.time, frequency: nil, isVoiced: false,
                midiNote: nil, rms: raw.rms
            )
        }

        // Anchor voiced but raw silent → use anchor pitch
        guard rawVoiced, let rawHz = raw.frequency,
              let anchorMidi = anchor.midiNote
        else { return anchor }

        let rawMidi = 69.0 + 12.0 * log2(rawHz / 440.0)
        let diff = rawMidi - anchorMidi

        // Within ±2 semitones → raw is correct, keep its precision
        if abs(diff) <= 2.0 { return raw }

        // Off by ~12 semitones → octave error
        if abs(abs(diff) - 12.0) <= 2.0 {
            return octaveCorrected(raw: raw, rawHz: rawHz, shift: diff > 0 ? 0.5 : 2.0)
        }

        // Off by ~24 semitones → two-octave error
        if abs(abs(diff) - 24.0) <= 2.0 {
            return octaveCorrected(raw: raw, rawHz: rawHz, shift: diff > 0 ? 0.25 : 4.0)
        }

        // Can't reconcile → trust the anchor
        return anchor
    }

    private static func octaveCorrected(
        raw: ReferencePitchFrame,
        rawHz: Double,
        shift: Double
    ) -> ReferencePitchFrame {
        let correctedHz = rawHz * shift
        let correctedMidi = 69.0 + 12.0 * log2(correctedHz / 440.0)
        return ReferencePitchFrame(
            time: raw.time, frequency: correctedHz, isVoiced: true,
            midiNote: correctedMidi, rms: raw.rms
        )
    }
}
