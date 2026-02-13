import Foundation

/// Maps frequencies to musical note names, MIDI numbers,
/// and cents deviation from the nearest note.
enum NoteMapper {
    private static let noteNames = [
        "C", "C#", "D", "D#", "E", "F",
        "F#", "G", "G#", "A", "A#", "B"
    ]

    /// Convert frequency in Hz to MIDI note number (fractional).
    static func frequencyToMidi(_ hz: Float) -> Float {
        guard hz > 0 else { return 0 }
        return 69.0 + 12.0 * log2(hz / 440.0)
    }

    /// Convert MIDI note number to frequency in Hz.
    static func midiToFrequency(_ midi: Float) -> Float {
        440.0 * pow(2.0, (midi - 69.0) / 12.0)
    }

    /// Get the nearest integer MIDI note for a frequency.
    static func nearestMidi(_ hz: Float) -> Int {
        Int(round(frequencyToMidi(hz)))
    }

    /// Compute cents deviation from the nearest note.
    /// Positive = sharp, negative = flat.
    static func centsDeviation(_ hz: Float) -> Float {
        let midi = frequencyToMidi(hz)
        let nearestNote = round(midi)
        return (midi - nearestNote) * 100.0
    }

    /// Get note info for a given MIDI number.
    static func noteInfo(forMidi midi: Int) -> NoteInfo {
        let noteName = noteNames[((midi % 12) + 12) % 12]
        let octave = (midi / 12) - 1
        return NoteInfo(
            name: noteName,
            octave: octave,
            midiNumber: midi
        )
    }

    /// Get note info for a given frequency.
    static func noteInfo(forFrequency hz: Float) -> NoteInfo {
        noteInfo(forMidi: nearestMidi(hz))
    }

    /// Compute cents between two frequencies.
    static func centsBetween(
        detected: Float,
        reference: Float
    ) -> Float {
        guard detected > 0, reference > 0 else { return 0 }
        return 1200.0 * log2(detected / reference)
    }
}
