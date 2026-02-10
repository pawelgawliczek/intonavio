import AVFoundation

/// Generates a synthetic sine wave and feeds it through
/// the same pitch detection pipeline. Used for testing
/// in the Simulator where the mic is unavailable.
final class ToneGenerator {
    private let detector = YINDetector()
    private let latencyTracker: LatencyTracker
    private var timer: Timer?
    private var phase: Double = 0

    var frequency: Float = 440.0
    var onPitchDetected: ((PitchResult) -> Void)?

    private(set) var isRunning = false

    init(latencyTracker: LatencyTracker) {
        self.latencyTracker = latencyTracker
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        phase = 0

        // Generate buffers at ~172Hz to match the real
        // sliding window rate (hopSize=256 at 44.1kHz).
        let interval = Double(PitchConstants.hopSize)
            / Double(PitchConstants.sampleRate)

        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.generateAndDetect()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Change the test tone frequency.
    func setFrequency(_ hz: Float) {
        frequency = hz
    }
}

// MARK: - Generation

private extension ToneGenerator {
    func generateAndDetect() {
        let tapTime = CFAbsoluteTimeGetCurrent()
        let sampleRate = Double(PitchConstants.sampleRate)
        let size = PitchConstants.analysisSize

        // Synthesize a sine wave buffer
        var samples = [Float](repeating: 0, count: size)
        let freq = Double(frequency)
        let phaseInc = 2.0 * .pi * freq / sampleRate

        for i in 0..<size {
            samples[i] = Float(sin(phase))
            phase += phaseInc
        }
        // Keep phase from growing unbounded
        if phase > 2.0 * .pi * 1000 {
            phase -= 2.0 * .pi * 1000
        }

        let detection = samples.withUnsafeBufferPointer {
            ptr -> (Float, Float)? in
            guard let base = ptr.baseAddress else {
                return nil
            }
            return detector.detect(base, count: size)
        }

        let processingMs = (CFAbsoluteTimeGetCurrent() - tapTime)
            * 1000.0
        latencyTracker.record(processingMs)

        guard let (detectedHz, confidence) = detection,
              confidence >= PitchConstants.confidenceThreshold
        else { return }

        let midi = NoteMapper.nearestMidi(detectedHz)
        let noteInfo = NoteMapper.noteInfo(forMidi: midi)
        let cents = NoteMapper.centsDeviation(detectedHz)

        let result = PitchResult(
            frequency: detectedHz,
            confidence: confidence,
            midiNote: midi,
            noteName: noteInfo.fullName,
            centsDeviation: cents,
            timestamp: CFAbsoluteTimeGetCurrent()
        )

        DispatchQueue.main.async { [weak self] in
            self?.onPitchDetected?(result)
        }
    }
}
