import XCTest
@testable import Intonavio

final class NoteMapperTests: XCTestCase {
    // MARK: - frequencyToMidi

    func testA4Is69() {
        let midi = NoteMapper.frequencyToMidi(440.0)
        XCTAssertEqual(midi, 69.0, accuracy: 0.01)
    }

    func testC4Is60() {
        let midi = NoteMapper.frequencyToMidi(261.63)
        XCTAssertEqual(midi, 60.0, accuracy: 0.1)
    }

    func testZeroFrequencyReturnsZero() {
        XCTAssertEqual(NoteMapper.frequencyToMidi(0), 0)
    }

    func testNegativeFrequencyReturnsZero() {
        XCTAssertEqual(NoteMapper.frequencyToMidi(-100), 0)
    }

    // MARK: - midiToFrequency

    func testMidi69Is440() {
        let freq = NoteMapper.midiToFrequency(69.0)
        XCTAssertEqual(freq, 440.0, accuracy: 0.01)
    }

    func testMidi60IsC4() {
        let freq = NoteMapper.midiToFrequency(60.0)
        XCTAssertEqual(freq, 261.63, accuracy: 0.1)
    }

    // MARK: - nearestMidi

    func testNearestMidiForA4() {
        XCTAssertEqual(NoteMapper.nearestMidi(440.0), 69)
    }

    func testNearestMidiForSlightlySharpA4() {
        // 443 Hz should still round to A4 (69)
        XCTAssertEqual(NoteMapper.nearestMidi(443.0), 69)
    }

    // MARK: - centsDeviation

    func testPerfectA4HasZeroCents() {
        let cents = NoteMapper.centsDeviation(440.0)
        XCTAssertEqual(cents, 0, accuracy: 0.5)
    }

    func testSharpPitchHasPositiveCents() {
        // Slightly sharp
        let cents = NoteMapper.centsDeviation(445.0)
        XCTAssertGreaterThan(cents, 0)
    }

    func testFlatPitchHasNegativeCents() {
        // Slightly flat
        let cents = NoteMapper.centsDeviation(435.0)
        XCTAssertLessThan(cents, 0)
    }

    // MARK: - centsBetween

    func testCentsBetweenSameFrequencyIsZero() {
        let cents = NoteMapper.centsBetween(detected: 440, reference: 440)
        XCTAssertEqual(cents, 0, accuracy: 0.01)
    }

    func testCentsBetweenOneSemitone() {
        // A#4 = 466.16 Hz, A4 = 440 Hz -> 100 cents
        let cents = NoteMapper.centsBetween(detected: 466.16, reference: 440.0)
        XCTAssertEqual(cents, 100, accuracy: 1.0)
    }

    func testCentsBetweenOneOctaveDown() {
        // 220 Hz vs 440 Hz -> -1200 cents
        let cents = NoteMapper.centsBetween(detected: 220, reference: 440)
        XCTAssertEqual(cents, -1200, accuracy: 0.1)
    }

    func testCentsBetweenZeroDetectedReturnsZero() {
        XCTAssertEqual(NoteMapper.centsBetween(detected: 0, reference: 440), 0)
    }

    func testCentsBetweenZeroReferenceReturnsZero() {
        XCTAssertEqual(NoteMapper.centsBetween(detected: 440, reference: 0), 0)
    }

    // MARK: - noteInfo

    func testNoteInfoForMidi69() {
        let info = NoteMapper.noteInfo(forMidi: 69)
        XCTAssertEqual(info.name, "A")
        XCTAssertEqual(info.octave, 4)
        XCTAssertEqual(info.fullName, "A4")
    }

    func testNoteInfoForMidi60() {
        let info = NoteMapper.noteInfo(forMidi: 60)
        XCTAssertEqual(info.name, "C")
        XCTAssertEqual(info.octave, 4)
        XCTAssertEqual(info.fullName, "C4")
    }

    func testNoteInfoForFrequency() {
        let info = NoteMapper.noteInfo(forFrequency: 440.0)
        XCTAssertEqual(info.fullName, "A4")
    }
}
