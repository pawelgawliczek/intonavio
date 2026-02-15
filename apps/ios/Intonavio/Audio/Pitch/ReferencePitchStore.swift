import Foundation

/// Loads reference pitch frames and provides O(1) lookup by time
/// and range queries for the piano roll.
final class ReferencePitchStore {
    private(set) var frames: [ReferencePitchFrame] = []
    private(set) var hopDuration: Double = 0
    private(set) var totalDuration: Double = 0
    private(set) var midiMin: Float = 48  // C3 default
    private(set) var midiMax: Float = 72  // C5 default
    private(set) var phrases: [ReferencePhraseInfo] = []

    var isEmpty: Bool { frames.isEmpty }
    var hasPhrases: Bool { !phrases.isEmpty }
    var phraseCount: Int { phrases.count }

    // MARK: - Loading

    /// Load reference pitch data from a local JSON file.
    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let pitchData = try JSONDecoder().decode(ReferencePitchData.self, from: data)
        applyData(pitchData)
        let count = frames.count
        let lo = midiMin
        let hi = midiMax
        AppLogger.pitch.info("Loaded \(count) reference frames (MIDI \(lo)-\(hi))")
    }

    /// Load directly from decoded data (used by exercise generator).
    func load(from pitchData: ReferencePitchData) {
        applyData(pitchData)
    }

    /// Reset all stored data.
    func reset() {
        frames = []
        hopDuration = 0
        totalDuration = 0
        midiMin = 48
        midiMax = 72
        phrases = []
    }

    // MARK: - Private

    private func applyData(_ pitchData: ReferencePitchData) {
        frames = pitchData.frames
        hopDuration = pitchData.hopDuration
        totalDuration = hopDuration * Double(frames.count)
        phrases = pitchData.phrases
        computeMidiRange()
    }

    private func computeMidiRange() {
        let voicedMidi = frames.compactMap { frame -> Float? in
            guard frame.isVoiced, frame.isAudible, let midi = frame.midiNote else { return nil }
            return Float(midi)
        }
        guard let minVal = voicedMidi.min(),
              let maxVal = voicedMidi.max() else { return }
        // Add 3-semitone padding above and below
        midiMin = minVal - 3
        midiMax = maxVal + 3
    }

    // MARK: - Queries

    /// O(1) lookup: get the reference frame at a given time.
    func frame(at time: Double) -> ReferencePitchFrame? {
        guard hopDuration > 0 else { return nil }
        let index = Int(time / hopDuration)
        guard index >= 0, index < frames.count else { return nil }
        return frames[index]
    }

    /// Get all frames within a time range (for piano roll rendering).
    func frames(from startTime: Double, to endTime: Double) -> ArraySlice<ReferencePitchFrame> {
        guard hopDuration > 0 else { return [] }
        let startIndex = max(0, Int(startTime / hopDuration))
        let endIndex = min(frames.count - 1, Int(endTime / hopDuration))
        guard startIndex <= endIndex else { return [] }
        return frames[startIndex...endIndex]
    }

    /// Compute the MIDI range for a specific time range (used for loop recalibration).
    func midiRange(from startTime: Double, to endTime: Double) -> (min: Float, max: Float)? {
        let sectionFrames = frames(from: startTime, to: endTime)
        let voicedMidi = sectionFrames.compactMap { frame -> Float? in
            guard frame.isVoiced, frame.isAudible, let midi = frame.midiNote else { return nil }
            return Float(midi)
        }
        guard let minVal = voicedMidi.min(),
              let maxVal = voicedMidi.max() else { return nil }
        return (min: minVal - 3, max: maxVal + 3)
    }

    /// Find the phrase containing the given playback time (linear scan).
    func phrase(at time: Double) -> ReferencePhraseInfo? {
        phrases.first { time >= $0.startTime && time <= $0.endTime }
    }
}
