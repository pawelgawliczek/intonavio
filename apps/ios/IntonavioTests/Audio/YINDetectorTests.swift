import XCTest
@testable import Intonavio

final class YINDetectorTests: XCTestCase {
    private let detector = YINDetector()
    private let sampleRate = PitchConstants.sampleRate

    // MARK: - Sine Wave Detection

    func testDetects440HzSine() {
        let buffer = generateSineWave(frequency: 440.0)
        let result = detectFromBuffer(buffer)
        XCTAssertNotNil(result, "Should detect 440Hz sine")
        if let (freq, _) = result {
            XCTAssertEqual(freq, 440.0, accuracy: 1.0, "Should detect ~440Hz")
        }
    }

    func testDetects261HzSine() {
        let buffer = generateSineWave(frequency: 261.63)
        let result = detectFromBuffer(buffer)
        XCTAssertNotNil(result, "Should detect C4 (~261.63Hz)")
        if let (freq, _) = result {
            XCTAssertEqual(freq, 261.63, accuracy: 2.0, "Should detect ~261.63Hz")
        }
    }

    func testDetects880HzSine() {
        let buffer = generateSineWave(frequency: 880.0)
        let result = detectFromBuffer(buffer)
        XCTAssertNotNil(result, "Should detect 880Hz (A5)")
        if let (freq, _) = result {
            XCTAssertEqual(freq, 880.0, accuracy: 2.0, "Should detect ~880Hz")
        }
    }

    func testDetectsLowE2() {
        let buffer = generateSineWave(frequency: 82.41)
        let result = detectFromBuffer(buffer)
        XCTAssertNotNil(result, "Should detect E2 (~82.41Hz)")
        if let (freq, _) = result {
            XCTAssertEqual(freq, 82.41, accuracy: 2.0)
        }
    }

    // MARK: - Silence & Noise

    func testSilenceReturnsNil() {
        let buffer = [Float](repeating: 0, count: PitchConstants.analysisSize)
        let result = detectFromBuffer(buffer)
        XCTAssertNil(result, "Silence should return nil")
    }

    func testLowAmplitudeNoiseReturnsNil() {
        var buffer = [Float](repeating: 0, count: PitchConstants.analysisSize)
        for i in 0..<buffer.count {
            buffer[i] = Float.random(in: -0.001...0.001)
        }
        let result = detectFromBuffer(buffer)
        // Low-amplitude noise should either return nil or low confidence
        if let (_, confidence) = result {
            XCTAssertLessThan(confidence, PitchConstants.confidenceThreshold)
        }
    }

    // MARK: - Confidence

    func testHighConfidenceForCleanSine() {
        let buffer = generateSineWave(frequency: 440.0)
        let result = detectFromBuffer(buffer)
        XCTAssertNotNil(result)
        if let (_, confidence) = result {
            XCTAssertGreaterThan(confidence, 0.9, "Clean sine should have >0.9 confidence")
        }
    }

    // MARK: - Edge Cases

    func testBufferTooSmallReturnsNil() {
        let buffer = [Float](repeating: 0, count: 10)
        let result = detectFromBuffer(buffer)
        XCTAssertNil(result, "Tiny buffer should return nil")
    }

    func testFrequencyBelowMinReturnsNil() {
        // Generate 40Hz - below min of 80Hz
        let buffer = generateSineWave(frequency: 40.0)
        let result = detectFromBuffer(buffer)
        XCTAssertNil(result, "Frequency below min range should return nil")
    }
}

// MARK: - Helpers

private extension YINDetectorTests {
    func generateSineWave(
        frequency: Float,
        amplitude: Float = 0.8,
        count: Int = PitchConstants.analysisSize
    ) -> [Float] {
        var buffer = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Float(i) / sampleRate
            buffer[i] = amplitude * sin(2.0 * .pi * frequency * t)
        }
        return buffer
    }

    func detectFromBuffer(_ buffer: [Float]) -> (Float, Float)? {
        buffer.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return nil }
            return detector.detect(base, count: buffer.count)
        }
    }
}
