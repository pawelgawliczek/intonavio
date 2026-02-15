import XCTest
@testable import Intonavio

final class ScoringEngineTests: XCTestCase {
    private var store: ReferencePitchStore!
    private var engine: ScoringEngine!

    override func setUp() {
        super.setUp()
        store = ReferencePitchStore()
        let frames = (0..<100).map { i in
            ReferencePitchFrame(
                time: Double(i) * 0.01,
                frequency: 440.0,
                isVoiced: true,
                midiNote: 69.0,
                rms: nil
            )
        }
        let data = ReferencePitchData(
            songId: nil,
            sampleRate: 44100,
            hopSize: 256,
            frameCount: frames.count,
            hopDuration: 0.01,
            frames: frames,
            phrases: []
        )
        store.load(from: data)
        engine = ScoringEngine(referenceStore: store)
    }

    // MARK: - Accuracy Classification (Advanced — ±25/40/60)

    func testExactMatchIsExcellent() {
        let accuracy = PitchAccuracy.classify(cents: 0, difficulty: .advanced)
        XCTAssertEqual(accuracy, .excellent)
    }

    func testAdvancedTwentyFiveCentsIsExcellent() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 25, difficulty: .advanced), .excellent)
    }

    func testAdvancedMinusTwentyFiveCentsIsExcellent() {
        XCTAssertEqual(PitchAccuracy.classify(cents: -25, difficulty: .advanced), .excellent)
    }

    func testAdvancedTwentySixCentsIsGood() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 26, difficulty: .advanced), .good)
    }

    func testAdvancedFortyCentsIsGood() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 40, difficulty: .advanced), .good)
    }

    func testAdvancedFortyOneCentsIsFair() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 41, difficulty: .advanced), .fair)
    }

    func testAdvancedSixtyCentsIsFair() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 60, difficulty: .advanced), .fair)
    }

    func testAdvancedSixtyOneCentsIsPoor() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 61, difficulty: .advanced), .poor)
    }

    func testAdvancedLargeCentsIsPoor() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 200, difficulty: .advanced), .poor)
    }

    // MARK: - Points (Advanced)

    func testExcellentGives100Points() {
        XCTAssertEqual(PitchAccuracy.excellent.points(difficulty: .advanced), 100)
    }

    func testGoodGives50Points() {
        XCTAssertEqual(PitchAccuracy.good.points(difficulty: .advanced), 50)
    }

    func testFairGives20Points() {
        XCTAssertEqual(PitchAccuracy.fair.points(difficulty: .advanced), 20)
    }

    func testPoorGives0Points() {
        XCTAssertEqual(PitchAccuracy.poor.points(difficulty: .advanced), 0)
    }

    // MARK: - Beginner Thresholds (±150/300/450)

    func testBeginnerExcellentAt150Cents() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 150, difficulty: .beginner), .excellent)
    }

    func testBeginner151CentsIsGood() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 151, difficulty: .beginner), .good)
    }

    func testBeginnerGoodAt300Cents() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 300, difficulty: .beginner), .good)
    }

    func testBeginnerFairAt450Cents() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 450, difficulty: .beginner), .fair)
    }

    func testBeginnerPoorAbove450Cents() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 451, difficulty: .beginner), .poor)
    }

    func testBeginnerGoodPoints() {
        XCTAssertEqual(PitchAccuracy.good.points(difficulty: .beginner), 75)
    }

    func testBeginnerFairPoints() {
        XCTAssertEqual(PitchAccuracy.fair.points(difficulty: .beginner), 40)
    }

    // MARK: - Intermediate Thresholds (2.5x — ±25/50/75)

    func testIntermediateExcellentAt25Cents() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 25, difficulty: .intermediate), .excellent)
    }

    func testIntermediateTwentySixCentsIsGood() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 26, difficulty: .intermediate), .good)
    }

    func testIntermediateGoodAt50Cents() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 50, difficulty: .intermediate), .good)
    }

    func testIntermediateFairAt75Cents() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 75, difficulty: .intermediate), .fair)
    }

    func testIntermediatePoorAbove75Cents() {
        XCTAssertEqual(PitchAccuracy.classify(cents: 76, difficulty: .intermediate), .poor)
    }

    func testIntermediateGoodPoints() {
        XCTAssertEqual(PitchAccuracy.good.points(difficulty: .intermediate), 60)
    }

    func testIntermediateFairPoints() {
        XCTAssertEqual(PitchAccuracy.fair.points(difficulty: .intermediate), 25)
    }

    // MARK: - Scoring Engine

    func testExactMatchScores100() {
        let detected = makePitchResult(frequency: 440.0)
        engine.evaluate(detected: detected, playbackTime: 0.0)
        XCTAssertEqual(engine.overallScore, 100, accuracy: 0.1)
    }

    func testUnvoicedDetectionDoesNotScore() {
        engine.evaluate(detected: nil, playbackTime: 0.0)
        XCTAssertEqual(engine.overallScore, 0)
        XCTAssertEqual(engine.pitchLog.count, 1)
    }

    func testUnvoicedReferenceSkipsScoring() {
        // Create a store with unvoiced reference
        let unvoicedStore = ReferencePitchStore()
        let frames = [ReferencePitchFrame(
            time: 0,
            frequency: nil,
            isVoiced: false,
            midiNote: nil,
            rms: nil
        )]
        let data = ReferencePitchData(
            songId: nil, sampleRate: 44100, hopSize: 256,
            frameCount: 1, hopDuration: 0.01, frames: frames,
            phrases: []
        )
        unvoicedStore.load(from: data)
        let unvoicedEngine = ScoringEngine(referenceStore: unvoicedStore)

        let detected = makePitchResult(frequency: 440.0)
        unvoicedEngine.evaluate(detected: detected, playbackTime: 0.0)
        XCTAssertEqual(unvoicedEngine.overallScore, 0)
        XCTAssertTrue(unvoicedEngine.pitchLog.isEmpty)
    }

    func testMixedAccuraciesCalculateCorrectScore() {
        // Frame 0: excellent (440Hz vs 440Hz ref)
        let perfect = makePitchResult(frequency: 440.0)
        engine.evaluate(detected: perfect, playbackTime: 0.0)

        // Frame 1: poor (very off)
        let poor = makePitchResult(frequency: 520.0)
        engine.evaluate(detected: poor, playbackTime: 0.01)

        // Score should be (100 + 0) / 2 = 50
        XCTAssertEqual(engine.overallScore, 50, accuracy: 1.0)
    }

    func testAllUnvoicedDetectionsScoreZero() {
        engine.evaluate(detected: nil, playbackTime: 0.0)
        engine.evaluate(detected: nil, playbackTime: 0.01)
        engine.evaluate(detected: nil, playbackTime: 0.02)
        XCTAssertEqual(engine.overallScore, 0)
    }

    func testResetClearsAllState() {
        let detected = makePitchResult(frequency: 440.0)
        engine.evaluate(detected: detected, playbackTime: 0.0)
        XCTAssertFalse(engine.pitchLog.isEmpty)

        engine.reset()
        XCTAssertTrue(engine.pitchLog.isEmpty)
        XCTAssertEqual(engine.overallScore, 0)
    }

    func testOutOfRangeTimeReturnsEarly() {
        let detected = makePitchResult(frequency: 440.0)
        engine.evaluate(detected: detected, playbackTime: 999.0)
        XCTAssertTrue(engine.pitchLog.isEmpty)
    }

    // MARK: - Transpose Scoring

    func testTransposeOctaveUpShiftsReference() {
        // Reference is 440Hz (A4). Transpose +12 shifts reference to 880Hz (A5).
        // Singing 880Hz should score excellent against transposed reference.
        engine.transposeSemitones = 12
        let detected = makePitchResult(frequency: 880.0)
        engine.evaluate(detected: detected, playbackTime: 0.0)
        XCTAssertEqual(engine.overallScore, 100, accuracy: 0.1)
    }

    func testTransposeOctaveDownShiftsReference() {
        // Reference is 440Hz (A4). Transpose -12 shifts reference to 220Hz (A3).
        // Singing 220Hz should score excellent against transposed reference.
        engine.transposeSemitones = -12
        let detected = makePitchResult(frequency: 220.0)
        engine.evaluate(detected: detected, playbackTime: 0.0)
        XCTAssertEqual(engine.overallScore, 100, accuracy: 0.1)
    }

    func testTransposeZeroMatchesOriginal() {
        // Transpose = 0 should behave identically to no transpose.
        engine.transposeSemitones = 0
        let detected = makePitchResult(frequency: 440.0)
        engine.evaluate(detected: detected, playbackTime: 0.0)
        XCTAssertEqual(engine.overallScore, 100, accuracy: 0.1)
    }

    func testTransposeMismatchScoresPoor() {
        // Reference is 440Hz. Transpose +12 → effective reference 880Hz.
        // Singing 440Hz against 880Hz reference should score poor.
        engine.transposeSemitones = 12
        let detected = makePitchResult(frequency: 440.0)
        engine.evaluate(detected: detected, playbackTime: 0.0)
        XCTAssertEqual(engine.currentAccuracy, .poor)
    }

    func testTransposeLogRecordsAdjustedReference() {
        engine.transposeSemitones = 12
        let detected = makePitchResult(frequency: 880.0)
        engine.evaluate(detected: detected, playbackTime: 0.0)

        let entry = engine.pitchLog.first
        XCTAssertNotNil(entry)
        // Adjusted reference should be ~880Hz (440 * 2^(12/12))
        XCTAssertEqual(entry?.referenceHz ?? 0, 880.0, accuracy: 0.1)
    }
}

// MARK: - Helpers

private extension ScoringEngineTests {
    func makePitchResult(frequency: Float) -> PitchResult {
        PitchResult(
            frequency: frequency,
            confidence: 0.95,
            midiNote: NoteMapper.nearestMidi(frequency),
            noteName: NoteMapper.noteInfo(forFrequency: frequency).fullName,
            centsDeviation: NoteMapper.centsDeviation(frequency),
            timestamp: CFAbsoluteTimeGetCurrent()
        )
    }
}
