import AVFoundation

/// Mixes vocal CAF + instrumental MP3 into an AAC M4A file using offline rendering.
enum BestTakeExporter {
    static func export(
        vocalURL: URL,
        instrumentalURL: URL,
        startOffset: TimeInterval,
        vocalSkip: TimeInterval = 0,
        outputName: String
    ) async throws -> URL {
        let vocal = try AVAudioFile(forReading: vocalURL)
        let instrumental = try AVAudioFile(forReading: instrumentalURL)

        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 2,
            interleaved: false
        )!

        let engine = AVAudioEngine()
        let vocalPlayer = AVAudioPlayerNode()
        let instrumentalPlayer = AVAudioPlayerNode()

        engine.attach(vocalPlayer)
        engine.attach(instrumentalPlayer)
        engine.connect(vocalPlayer, to: engine.mainMixerNode, format: vocal.processingFormat)
        engine.connect(
            instrumentalPlayer,
            to: engine.mainMixerNode,
            format: instrumental.processingFormat
        )
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)

        try engine.enableManualRenderingMode(
            .offline,
            format: outputFormat,
            maximumFrameCount: 4096
        )
        try engine.start()

        // Schedule vocal, skipping frames to align with instrumental
        let vocalSR = vocal.processingFormat.sampleRate
        let vocalSkipFrames = AVAudioFramePosition(vocalSkip * vocalSR)
        let vocalRemaining = AVAudioFrameCount(max(0, vocal.length - vocalSkipFrames))
        if vocalRemaining > 0 {
            vocalPlayer.scheduleSegment(
                vocal,
                startingFrame: vocalSkipFrames,
                frameCount: vocalRemaining,
                at: nil,
                completionHandler: nil
            )
        }

        // Schedule instrumental from startOffset
        let instSampleRate = instrumental.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(startOffset * instSampleRate)
        let instRemaining = AVAudioFrameCount(max(0, instrumental.length - startFrame))
        if instRemaining > 0 {
            instrumentalPlayer.scheduleSegment(
                instrumental,
                startingFrame: startFrame,
                frameCount: instRemaining,
                at: nil,
                completionHandler: nil
            )
        }

        vocalPlayer.play()
        instrumentalPlayer.play()

        // Calculate total frames based on vocal duration (minus latency trim)
        let vocalDuration = Double(vocal.length) / vocalSR - vocalSkip
        let instDuration = (Double(instrumental.length) / instSampleRate) - startOffset
        let totalDuration = min(max(0, vocalDuration), instDuration)
        let totalFrames = AVAudioFramePosition(totalDuration * outputFormat.sampleRate)

        // Output file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(outputName).m4a")
        try? FileManager.default.removeItem(at: outputURL)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000
        ]
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: outputSettings
        )

        let renderBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: 4096
        )!

        var framesRendered: AVAudioFramePosition = 0

        while framesRendered < totalFrames {
            let status = try engine.renderOffline(4096, to: renderBuffer)
            switch status {
            case .success:
                try outputFile.write(from: renderBuffer)
                framesRendered += AVAudioFramePosition(renderBuffer.frameLength)
            case .insufficientDataFromInputNode:
                continue
            case .cannotDoInCurrentContext:
                try await Task.sleep(nanoseconds: 10_000_000)
            case .error:
                throw ExportError.renderFailed
            @unknown default:
                throw ExportError.renderFailed
            }

            if Task.isCancelled { throw CancellationError() }
        }

        engine.stop()
        AppLogger.recording.info("Exported best take → \(outputURL.lastPathComponent)")
        return outputURL
    }

    enum ExportError: LocalizedError {
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .renderFailed: return "Offline audio render failed"
            }
        }
    }
}
