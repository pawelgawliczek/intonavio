import AVFoundation

/// Manages AVAudioEngine setup and microphone tap for
/// real-time pitch detection using a sliding window.
///
/// Accumulates samples in a ring buffer and runs YIN every
/// `hopSize` new samples on the last `analysisSize` samples.
/// This gives ~172 pitch readings/sec instead of ~43.
final class AudioEngineManager {
    private let engine = AVAudioEngine()
    private let detector = YINDetector()
    private let latencyTracker: LatencyTracker

    /// Ring buffer accumulating mic samples.
    private var ringBuffer: [Float]
    private var writeIndex: Int = 0
    /// How many new samples since last YIN run.
    private var samplesAccumulated: Int = 0

    var onPitchDetected: ((PitchResult) -> Void)?

    private(set) var isRunning = false

    init(latencyTracker: LatencyTracker) {
        self.latencyTracker = latencyTracker
        // Pre-allocate ring buffer (2x analysis size for safety)
        self.ringBuffer = [Float](
            repeating: 0,
            count: PitchConstants.analysisSize * 2
        )
    }

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker]
        )
        // Request smallest IO buffer the hardware supports
        try session.setPreferredIOBufferDuration(
            Double(PitchConstants.ioBufferSize)
                / Double(PitchConstants.sampleRate)
        )
        try session.setActive(true)
    }

    func start() throws {
        guard !isRunning else { return }
        try configureSession()

        writeIndex = 0
        samplesAccumulated = 0
        ringBuffer = [Float](
            repeating: 0,
            count: PitchConstants.analysisSize * 2
        )

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: PitchConstants.ioBufferSize,
            format: format
        ) { [weak self] buffer, time in
            self?.processBuffer(buffer, time: time)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}

// MARK: - Sliding Window Processing

private extension AudioEngineManager {
    func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        time: AVAudioTime
    ) {
        guard let channelData = buffer.floatChannelData else {
            return
        }

        let frameCount = Int(buffer.frameLength)
        let rawPtr = channelData[0]
        let ringSize = ringBuffer.count

        // Append new samples to ring buffer
        for i in 0..<frameCount {
            ringBuffer[writeIndex] = rawPtr[i]
            writeIndex = (writeIndex + 1) % ringSize
            samplesAccumulated += 1

            // Run YIN every hopSize new samples
            if samplesAccumulated >= PitchConstants.hopSize {
                samplesAccumulated = 0
                runDetection()
            }
        }
    }

    func runDetection() {
        let tapTime = CFAbsoluteTimeGetCurrent()
        let size = PitchConstants.analysisSize
        let ringSize = ringBuffer.count

        // Extract the last `analysisSize` samples into a
        // contiguous buffer for YIN. The start position is
        // `writeIndex - analysisSize` wrapped around.
        var window = [Float](repeating: 0, count: size)
        let start = (writeIndex - size + ringSize) % ringSize
        for i in 0..<size {
            window[i] = ringBuffer[(start + i) % ringSize]
        }

        guard let (frequency, confidence) = window.withUnsafeBufferPointer({
            ptr -> (Float, Float)? in
            guard let base = ptr.baseAddress else { return nil }
            return detector.detect(base, count: size)
        }) else { return }

        let processingMs = (CFAbsoluteTimeGetCurrent() - tapTime)
            * 1000.0
        latencyTracker.record(processingMs)

        guard confidence >= PitchConstants.confidenceThreshold
        else { return }

        let midi = NoteMapper.nearestMidi(frequency)
        let noteInfo = NoteMapper.noteInfo(forMidi: midi)
        let cents = NoteMapper.centsDeviation(frequency)

        let result = PitchResult(
            frequency: frequency,
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
