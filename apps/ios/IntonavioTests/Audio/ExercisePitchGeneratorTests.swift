import XCTest
@testable import Intonavio

final class ExercisePitchGeneratorTests: XCTestCase {
    private let hopDuration = Double(PitchConstants.hopSize) / Double(PitchConstants.sampleRate)

    // MARK: - Sustained Note

    func testSustainedC4At80BPM() {
        let notes = [ExerciseNote(midiNote: 60, durationBeats: 1.0)]
        let data = ExercisePitchGenerator.generate(notes: notes, tempo: 80)

        XCTAssertGreaterThan(data.frameCount, 0)
        XCTAssertEqual(data.hopDuration, hopDuration, accuracy: 0.0001)

        // At 80 BPM, 1 beat = 0.75s, frames = 0.75 / hopDuration
        let expectedFrames = Int(0.75 / hopDuration)
        XCTAssertEqual(data.frameCount, expectedFrames, accuracy: 2)

        // All frames should be voiced at C4 frequency (~261.63 Hz)
        for frame in data.frames {
            XCTAssertTrue(frame.isVoiced)
            XCTAssertEqual(frame.frequency!, 261.63, accuracy: 1.0)
            XCTAssertEqual(frame.midiNote, 60)
        }
    }

    func testSustainedA4At120BPM() {
        let notes = [ExerciseNote(midiNote: 69, durationBeats: 2.0)]
        let data = ExercisePitchGenerator.generate(notes: notes, tempo: 120)

        // At 120 BPM, 2 beats = 1.0s
        let expectedDuration = 1.0
        let actualDuration = Double(data.frameCount) * data.hopDuration
        XCTAssertEqual(actualDuration, expectedDuration, accuracy: 0.01)

        // Should be A4 (~440 Hz)
        let firstFrame = data.frames.first!
        XCTAssertEqual(firstFrame.frequency!, 440.0, accuracy: 0.5)
    }

    // MARK: - Rests

    func testRestProducesUnvoicedFrames() {
        let notes = [ExerciseNote.rest(durationBeats: 1.0)]
        let data = ExercisePitchGenerator.generate(notes: notes, tempo: 60)

        XCTAssertGreaterThan(data.frameCount, 0)
        for frame in data.frames {
            XCTAssertFalse(frame.isVoiced)
            XCTAssertNil(frame.frequency)
            XCTAssertNil(frame.midiNote)
        }
    }

    // MARK: - Vibrato

    func testVibratoOscillatesWithinRange() {
        let notes = [
            ExerciseNote(midiNote: 60, durationBeats: 4.0, hasVibrato: true)
        ]
        let data = ExercisePitchGenerator.generate(notes: notes, tempo: 60)

        let baseFreq = 261.63
        let maxDeviation = 50.0 // cents - vibrato should be within ±50 cents

        // Skip initial ramp-in period (first 0.3s)
        let rampFrames = Int(0.3 / data.hopDuration)
        let afterRamp = data.frames.dropFirst(rampFrames)
        XCTAssertFalse(afterRamp.isEmpty)

        var hasAbove = false
        var hasBelow = false

        for frame in afterRamp {
            let cents = 1200.0 * log2(frame.frequency! / baseFreq)
            XCTAssertLessThan(abs(cents), maxDeviation, "Vibrato should stay within ±\(maxDeviation) cents")
            if cents > 5 { hasAbove = true }
            if cents < -5 { hasBelow = true }
        }

        XCTAssertTrue(hasAbove, "Vibrato should oscillate above base frequency")
        XCTAssertTrue(hasBelow, "Vibrato should oscillate below base frequency")
    }

    // MARK: - Multiple Notes

    func testMultipleNotesSequence() {
        let notes = [
            ExerciseNote(midiNote: 60), // C4
            ExerciseNote(midiNote: 64), // E4
            ExerciseNote(midiNote: 67), // G4
        ]
        let data = ExercisePitchGenerator.generate(notes: notes, tempo: 60)

        // At 60 BPM, each beat = 1s, 3 beats = 3s
        let expectedDuration = 3.0
        let actualDuration = Double(data.frameCount) * data.hopDuration
        XCTAssertEqual(actualDuration, expectedDuration, accuracy: 0.02)

        // First frame should be C4, somewhere in the middle E4, end G4
        XCTAssertEqual(data.frames.first?.midiNote, 60)
        XCTAssertEqual(data.frames.last?.midiNote, 67)
    }

    // MARK: - Tempo Scaling

    func testTempoAffectsFrameCount() {
        let notes = [ExerciseNote(midiNote: 60, durationBeats: 1.0)]
        let slow = ExercisePitchGenerator.generate(notes: notes, tempo: 60)
        let fast = ExercisePitchGenerator.generate(notes: notes, tempo: 120)

        // Slow should have roughly 2x the frames of fast
        let ratio = Double(slow.frameCount) / Double(fast.frameCount)
        XCTAssertEqual(ratio, 2.0, accuracy: 0.1)
    }
}
