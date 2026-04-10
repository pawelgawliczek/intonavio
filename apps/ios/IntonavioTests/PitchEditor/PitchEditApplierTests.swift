import XCTest
@testable import Intonavio

final class PitchEditApplierTests: XCTestCase {
    private let hop = 0.01
    private let eps = 1e-6

    // MARK: - Fixtures

    private func makeBase(count: Int = 100, hz: Double = 220.0) -> [ReferencePitchFrame] {
        (0..<count).map { i in
            ReferencePitchFrame(
                time: Double(i) * hop,
                frequency: hz,
                isVoiced: true,
                midiNote: 69.0 + 12.0 * log2(hz / 440.0),
                rms: 0.1
            )
        }
    }

    private func makeScript(ops: [PitchEditOp]) -> PitchEditScript {
        PitchEditScript(
            songId: "song-1",
            baseVariantId: "base",
            operations: ops,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: - Round trip

    func testScriptRoundTripAllOps() throws {
        let passage = [
            ReferencePitchFrame(time: 0.0, frequency: 440.0, isVoiced: true, midiNote: 69, rms: 0.1)
        ]
        let ops: [PitchEditOp] = [
            .useVariant(id: UUID(), range: TimeRange(start: 0.0, end: 0.1), source: .studio),
            .despike(id: UUID(), range: TimeRange(start: 0.1, end: 0.2), maxJumpSemitones: 4),
            .mute(id: UUID(), range: TimeRange(start: 0.2, end: 0.3)),
            .shiftOctave(id: UUID(), range: TimeRange(start: 0.3, end: 0.4), octaves: 1),
            .addPassage(id: UUID(), range: TimeRange(start: 0.4, end: 0.5),
                        frames: passage, mode: .replace),
            .fillGaps(id: UUID(), range: TimeRange(start: 0.5, end: 0.6)),
        ]
        let script = makeScript(ops: ops)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let data = try enc.encode(script)
        let decoded = try dec.decode(PitchEditScript.self, from: data)
        XCTAssertEqual(decoded, script)
    }

    // MARK: - Store

    func testStoreSaveLoadDeleteEditedIds() throws {
        let songId = "test-song-\(UUID().uuidString)"
        defer { PitchEditScriptStore.delete(songId: songId) }

        XCTAssertFalse(PitchEditScriptStore.exists(songId: songId))
        let script = makeScript(ops: [])
        var mutable = script
        mutable = PitchEditScript(
            songId: songId,
            baseVariantId: "base",
            operations: [],
            updatedAt: script.updatedAt
        )
        try PitchEditScriptStore.save(mutable)
        XCTAssertTrue(PitchEditScriptStore.exists(songId: songId))
        XCTAssertTrue(PitchEditScriptStore.editedSongIds().contains(songId))

        let loaded = PitchEditScriptStore.load(songId: songId)
        XCTAssertEqual(loaded, mutable)

        PitchEditScriptStore.delete(songId: songId)
        XCTAssertFalse(PitchEditScriptStore.exists(songId: songId))
        XCTAssertFalse(PitchEditScriptStore.editedSongIds().contains(songId))
    }

    // MARK: - Apply

    func testApplyEmptyOpsReturnsBase() {
        let base = makeBase()
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [])
        )
        XCTAssertEqual(out, base)
    }

    func testUseVariantReplacesRange() {
        let base = makeBase()
        let other = makeBase(hz: 330.0)
        let op: PitchEditOp = .useVariant(
            id: UUID(),
            range: TimeRange(start: 0.2, end: 0.5),
            source: .draft
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [.draft: other],
            script: makeScript(ops: [op])
        )
        for i in 20..<50 {
            XCTAssertEqual(out[i].frequency ?? -1, 330.0, accuracy: eps)
        }
        XCTAssertEqual(out[19].frequency ?? -1, 220.0, accuracy: eps)
        XCTAssertEqual(out[50].frequency ?? -1, 220.0, accuracy: eps)
    }

    func testDespikeRemovesSpike() {
        var base = makeBase()
        base[50] = ReferencePitchFrame(
            time: 0.5,
            frequency: 440.0,
            isVoiced: true,
            midiNote: 69,
            rms: 0.1
        )
        let op: PitchEditOp = .despike(
            id: UUID(),
            range: TimeRange(start: 0.4, end: 0.6),
            maxJumpSemitones: 4
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        let expected = (220.0 * 220.0).squareRoot()
        XCTAssertEqual(out[50].frequency ?? -1, expected, accuracy: eps)
    }

    func testMuteSetsUnvoicedInRange() {
        let base = makeBase()
        let op: PitchEditOp = .mute(id: UUID(), range: TimeRange(start: 0.3, end: 0.5))
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        for i in 30..<50 {
            XCTAssertFalse(out[i].isVoiced)
            XCTAssertNil(out[i].frequency)
            XCTAssertNil(out[i].midiNote)
        }
        XCTAssertTrue(out[29].isVoiced)
        XCTAssertTrue(out[50].isVoiced)
    }

    func testShiftOctaveUp() {
        let base = makeBase()
        let op: PitchEditOp = .shiftOctave(
            id: UUID(),
            range: TimeRange(start: 0.1, end: 0.2),
            octaves: 1
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        let baseMidi = 69.0 + 12.0 * log2(220.0 / 440.0)
        for i in 10..<20 {
            XCTAssertEqual(out[i].frequency ?? -1, 440.0, accuracy: eps)
            XCTAssertEqual(out[i].midiNote ?? -1, baseMidi + 12, accuracy: eps)
        }
        XCTAssertEqual(out[9].frequency ?? -1, 220.0, accuracy: eps)
    }

    func testAddPassageReplaceOverwrites() {
        let base = makeBase()
        let passage = (0..<10).map { i in
            ReferencePitchFrame(
                time: Double(i) * hop,
                frequency: 550.0,
                isVoiced: true,
                midiNote: 73,
                rms: 0.2
            )
        }
        let op: PitchEditOp = .addPassage(
            id: UUID(),
            range: TimeRange(start: 0.1, end: 0.2),
            frames: passage,
            mode: .replace
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        for i in 10..<20 {
            XCTAssertEqual(out[i].frequency ?? -1, 550.0, accuracy: eps)
        }
        XCTAssertEqual(out[9].frequency ?? -1, 220.0, accuracy: eps)
    }

    func testAddPassageAdditiveFillsOnlyUnvoiced() {
        var base = makeBase()
        for i in 10..<15 {
            let f = base[i]
            base[i] = ReferencePitchFrame(
                time: f.time,
                frequency: nil,
                isVoiced: false,
                midiNote: nil,
                rms: f.rms
            )
        }
        let passage = (0..<10).map { i in
            ReferencePitchFrame(
                time: Double(i) * hop,
                frequency: 550.0,
                isVoiced: true,
                midiNote: 73,
                rms: 0.2
            )
        }
        let op: PitchEditOp = .addPassage(
            id: UUID(),
            range: TimeRange(start: 0.1, end: 0.2),
            frames: passage,
            mode: .additive
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        // Unvoiced frames 10..15 were filled.
        for i in 10..<15 {
            XCTAssertEqual(out[i].frequency ?? -1, 550.0, accuracy: eps)
            XCTAssertTrue(out[i].isVoiced)
        }
        // Voiced frames 15..20 were left alone.
        for i in 15..<20 {
            XCTAssertEqual(out[i].frequency ?? -1, 220.0, accuracy: eps)
        }
    }

    // MARK: - Fill Gaps

    func testFillGapsInterpolatesAcrossUnvoiced() {
        var base = makeBase(hz: 220.0)
        // Create a 5-frame gap at indices 20..24
        for i in 20..<25 {
            base[i] = ReferencePitchFrame(
                time: Double(i) * hop,
                frequency: nil,
                isVoiced: false,
                midiNote: nil,
                rms: 0.1
            )
        }
        // Set right anchor to 440 Hz so interpolation is clear
        let rightMidi = 69.0 + 12.0 * log2(440.0 / 440.0) // = 69.0
        base[25] = ReferencePitchFrame(
            time: 25 * hop,
            frequency: 440.0,
            isVoiced: true,
            midiNote: rightMidi,
            rms: 0.1
        )
        let op: PitchEditOp = .fillGaps(
            id: UUID(),
            range: TimeRange(start: 0.0, end: 0.3)
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        // All gap frames should now be voiced
        for i in 20..<25 {
            XCTAssertTrue(out[i].isVoiced)
            XCTAssertNotNil(out[i].frequency)
        }
        // Left anchor at 19 = 220 Hz, right anchor at 25 = 440 Hz
        // Frame 20: t = 1/6 of span → 220 + (440-220)*1/6 ≈ 256.67
        let leftHz = 220.0
        let rHz = 440.0
        for i in 20..<25 {
            let t = Double(i - 19) / Double(25 - 19)
            let expected = leftHz + (rHz - leftHz) * t
            XCTAssertEqual(out[i].frequency ?? -1, expected, accuracy: 0.01)
        }
        // Frames outside gap are unchanged
        XCTAssertEqual(out[19].frequency ?? -1, 220.0, accuracy: eps)
        XCTAssertEqual(out[25].frequency ?? -1, 440.0, accuracy: eps)
    }

    func testFillGapsLeavesVoicedFramesAlone() {
        let base = makeBase(hz: 220.0)
        let op: PitchEditOp = .fillGaps(
            id: UUID(),
            range: TimeRange(start: 0.0, end: 1.0)
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        XCTAssertEqual(out, base)
    }

    func testFillGapsSkipsGapAtRangeBoundary() {
        var base = makeBase(hz: 220.0)
        // Gap at the very start (no left anchor within range)
        for i in 0..<5 {
            base[i] = ReferencePitchFrame(
                time: Double(i) * hop,
                frequency: nil,
                isVoiced: false,
                midiNote: nil,
                rms: 0.1
            )
        }
        let op: PitchEditOp = .fillGaps(
            id: UUID(),
            range: TimeRange(start: 0.0, end: 0.1)
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        // Gap at start has no left anchor → stays unvoiced
        for i in 0..<5 {
            XCTAssertFalse(out[i].isVoiced)
        }
    }

    func testFillGapsHandlesLowRmsAsGap() {
        var base = makeBase(hz: 220.0)
        // Frames 20..24: voiced but RMS below audibility threshold (0.02)
        for i in 20..<25 {
            base[i] = ReferencePitchFrame(
                time: Double(i) * hop,
                frequency: 220.0,
                isVoiced: true,
                midiNote: 57.0,
                rms: 0.001
            )
        }
        base[25] = ReferencePitchFrame(
            time: 25 * hop,
            frequency: 440.0,
            isVoiced: true,
            midiNote: 69.0,
            rms: 0.1
        )
        let op: PitchEditOp = .fillGaps(
            id: UUID(),
            range: TimeRange(start: 0.0, end: 0.3)
        )
        let out = PitchEditApplier.apply(
            base: base,
            hopDuration: hop,
            otherVariants: [:],
            script: makeScript(ops: [op])
        )
        // Low-RMS frames should be filled with interpolated values
        for i in 20..<25 {
            XCTAssertTrue(out[i].isVoiced)
            XCTAssertNotNil(out[i].rms)
            XCTAssertGreaterThanOrEqual(out[i].rms ?? 0, ReferencePitchFrame.rmsThreshold)
        }
        // Pitch should interpolate between 220 (left) and 440 (right)
        let leftHz = 220.0
        let rHz = 440.0
        for i in 20..<25 {
            let t = Double(i - 19) / Double(25 - 19)
            let expected = leftHz + (rHz - leftHz) * t
            XCTAssertEqual(out[i].frequency ?? -1, expected, accuracy: 0.01)
        }
    }
}
