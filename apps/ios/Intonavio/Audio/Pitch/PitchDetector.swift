import Accelerate
import AVFoundation

/// Captures microphone input via a shared AudioEngine and runs
/// YIN pitch detection on a sliding window. Dispatches results to main thread.
///
/// Uses the shared engine's input node so voice processing (AEC)
/// can cancel stem audio from the mic signal.
@Observable
final class PitchDetector {
    var latestResult: PitchResult?
    private(set) var isRunning = false

    private let audioEngine: AudioEngine
    private var detector = YINDetector()

    /// Ring buffer accumulating mic samples.
    private var ringBuffer: [Float] = []
    private var writeIndex: Int = 0
    private var samplesAccumulated: Int = 0

    var onPitchDetected: ((PitchResult) -> Void)?

    init(engine: AudioEngine) {
        self.audioEngine = engine
    }

    // MARK: - Lifecycle

    func start() throws {
        guard !isRunning else { return }

        // Ensure engine is running (idempotent if StemPlayer already started it).
        // VP + audio session are configured inside start().
        try audioEngine.start()

        let format = audioEngine.inputFormat
        guard format.sampleRate > 0, format.channelCount > 0 else {
            AppLogger.pitch.error(
                "Invalid input format: \(format.sampleRate)Hz, \(format.channelCount)ch"
            )
            return
        }

        writeIndex = 0
        samplesAccumulated = 0
        ringBuffer = [Float](
            repeating: 0,
            count: PitchConstants.analysisSize * 2
        )

        let actualSampleRate = Float(format.sampleRate)

        // Rebuild detector with the real sample rate (VP may use 48000, not 44100)
        detector = YINDetector(
            sampleRate: actualSampleRate,
            threshold: PitchConstants.yinThreshold,
            minLag: Int(actualSampleRate / PitchConstants.maxFrequency),
            maxLag: Int(actualSampleRate / PitchConstants.minFrequency)
        )

        audioEngine.inputTapRouter.addConsumer(
            id: "pitch",
            bufferSize: PitchConstants.ioBufferSize,
            format: format
        ) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        isRunning = true
        AppLogger.pitch.info(
            "PitchDetector started — sampleRate=\(actualSampleRate) channels=\(format.channelCount)"
        )
    }

    func stop() {
        guard isRunning else { return }
        audioEngine.inputTapRouter.removeConsumer(id: "pitch")
        isRunning = false
        latestResult = nil
        AppLogger.pitch.info("PitchDetector stopped")
    }

    deinit {
        if isRunning {
            audioEngine.inputTapRouter.removeConsumer(id: "pitch")
        }
    }
}

// MARK: - Sliding Window Processing

private extension PitchDetector {
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let rawPtr = channelData[0]
        let ringSize = ringBuffer.count
        let gain = audioEngine.isBluetoothRoute
            ? PitchConstants.bluetoothMicGain
            : Float(1.0)

        for i in 0..<frameCount {
            ringBuffer[writeIndex] = rawPtr[i] * gain
            writeIndex = (writeIndex + 1) % ringSize
            samplesAccumulated += 1

            if samplesAccumulated >= PitchConstants.hopSize {
                samplesAccumulated = 0
                runDetection()
            }
        }
    }

    func runDetection() {
        let size = PitchConstants.analysisSize
        let ringSize = ringBuffer.count

        var window = [Float](repeating: 0, count: size)
        let start = (writeIndex - size + ringSize) % ringSize
        for i in 0..<size {
            window[i] = ringBuffer[(start + i) % ringSize]
        }

        // RMS noise gate — skip detection when signal is below noise floor
        var rms: Float = 0
        vDSP_rmsqv(window, 1, &rms, vDSP_Length(size))
        guard rms >= PitchConstants.rmsNoiseFloor else { return }

        guard let (frequency, confidence) = window.withUnsafeBufferPointer({
            ptr -> (Float, Float)? in
            guard let base = ptr.baseAddress else { return nil }
            return detector.detect(base, count: size)
        }) else { return }

        guard confidence >= PitchConstants.confidenceThreshold else { return }

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
            self?.latestResult = result
            self?.onPitchDetected?(result)
        }
    }
}
