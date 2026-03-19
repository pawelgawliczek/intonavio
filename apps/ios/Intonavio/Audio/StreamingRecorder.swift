import AVFoundation

/// Streams mic input to a CAF file via InputTapRouter.
/// Writes happen on a serial DispatchQueue so the audio thread is never blocked.
final class StreamingRecorder {
    private let writeQueue = DispatchQueue(label: "com.intonavio.streamingRecorder")
    private var audioFile: AVAudioFile?
    private var fileURL: URL?
    private weak var router: InputTapRouter?

    private static let consumerId = "streamingRecorder"

    /// Start streaming mic audio to a CAF file at the given URL.
    func startStreaming(router: InputTapRouter, to url: URL, format: AVAudioFormat) throws {
        stopStreaming()

        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        self.audioFile = file
        self.fileURL = url
        self.router = router

        router.addConsumer(
            id: Self.consumerId,
            bufferSize: PitchConstants.ioBufferSize,
            format: format
        ) { [weak self] buffer, _ in
            self?.writeBuffer(buffer)
        }

        AppLogger.recording.info("StreamingRecorder started → \(url.lastPathComponent)")
    }

    /// Stop streaming and close the file.
    func stopStreaming() {
        router?.removeConsumer(id: Self.consumerId)
        router = nil

        writeQueue.sync { [weak self] in
            self?.audioFile = nil
        }
    }

    /// Stop streaming and delete the temp file.
    func discard() {
        let url = fileURL
        stopStreaming()

        if let url {
            try? FileManager.default.removeItem(at: url)
            AppLogger.recording.info("StreamingRecorder discarded temp file")
        }
        fileURL = nil
    }

    private func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        writeQueue.async { [weak self] in
            guard let file = self?.audioFile else { return }
            do {
                try file.write(from: buffer)
            } catch {
                AppLogger.recording.error(
                    "StreamingRecorder write failed: \(error.localizedDescription)"
                )
            }
        }
    }

    deinit {
        discard()
    }
}
