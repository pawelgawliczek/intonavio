import AVFoundation
import Accelerate

/// Captures microphone input to a pre-allocated PCM buffer via the shared
/// AudioEngine tap. Writes to a CAF file on stop. Coexists with PitchDetector.
@Observable
final class AudioRecorder {
    private(set) var isRecording = false
    private(set) var currentDuration: TimeInterval = 0
    private(set) var audioLevel: Float = 0

    private let audioEngine: AudioEngine
    private var buffer: [Float] = []
    private var writeIndex = 0
    private var sampleRate: Double = 0
    private let maxDuration: TimeInterval = 30.0

    init(engine: AudioEngine) {
        self.audioEngine = engine
    }

    // MARK: - Lifecycle

    func startRecording() throws {
        guard !isRecording else { return }

        try audioEngine.start()

        let format = audioEngine.inputFormat
        sampleRate = format.sampleRate
        guard sampleRate > 0 else {
            AppLogger.audio.error("AudioRecorder: invalid sample rate")
            return
        }

        let maxSamples = Int(sampleRate * maxDuration)
        buffer = [Float](repeating: 0, count: maxSamples)
        writeIndex = 0
        currentDuration = 0
        audioLevel = 0

        audioEngine.installInputTap(
            bufferSize: PitchConstants.ioBufferSize,
            format: format
        ) { [weak self] pcmBuffer, _ in
            self?.processBuffer(pcmBuffer)
        }

        isRecording = true
        AppLogger.audio.info("AudioRecorder started — sampleRate=\(self.sampleRate)")
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.removeInputTap()
        isRecording = false
        let samples = writeIndex
        let dur = currentDuration
        AppLogger.audio.info(
            "AudioRecorder stopped — \(samples) samples (\(dur)s)"
        )
    }

    /// Write the recorded buffer to a CAF file. Returns the file URL.
    func writeToFile(directory: URL) throws -> URL {
        let fileURL = directory.appendingPathComponent("audio.caf")

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(
            forWriting: fileURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        let sampleCount = writeIndex
        guard sampleCount > 0 else {
            throw RecordingError.emptyBuffer
        }

        let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(sampleCount)
        )!
        pcmBuffer.frameLength = AVAudioFrameCount(sampleCount)

        let destination = pcmBuffer.floatChannelData![0]
        buffer.withUnsafeBufferPointer { src in
            destination.update(from: src.baseAddress!, count: sampleCount)
        }

        try file.write(from: pcmBuffer)
        AppLogger.audio.info("Wrote \(sampleCount) samples to \(fileURL.lastPathComponent)")
        return fileURL
    }

    /// Access the raw recorded samples for offline analysis.
    var recordedSamples: ArraySlice<Float> {
        buffer[0..<writeIndex]
    }

    var recordedSampleRate: Double { sampleRate }
}

// MARK: - Private

private extension AudioRecorder {
    func processBuffer(_ pcmBuffer: AVAudioPCMBuffer) {
        guard let channelData = pcmBuffer.floatChannelData else { return }

        let frameCount = Int(pcmBuffer.frameLength)
        let rawPtr = channelData[0]
        let maxSamples = buffer.count

        for i in 0..<frameCount {
            guard writeIndex < maxSamples else {
                DispatchQueue.main.async { [weak self] in
                    self?.stopRecording()
                }
                return
            }
            buffer[writeIndex] = rawPtr[i]
            writeIndex += 1
        }

        // Compute RMS for level meter (every buffer callback)
        var rms: Float = 0
        vDSP_rmsqv(rawPtr, 1, &rms, vDSP_Length(frameCount))

        let elapsed = Double(writeIndex) / sampleRate

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = rms
            self?.currentDuration = elapsed
        }
    }
}

enum RecordingError: Error, LocalizedError {
    case emptyBuffer
    case analysisFailed

    var errorDescription: String? {
        switch self {
        case .emptyBuffer: return "No audio was recorded"
        case .analysisFailed: return "Could not detect any pitched notes"
        }
    }
}
