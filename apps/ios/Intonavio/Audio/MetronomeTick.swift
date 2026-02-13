import AVFoundation

/// Plays a metronome click at a given BPM using a short sine burst.
final class MetronomeTick {
    private var timer: Timer?
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var tickBuffer: AVAudioPCMBuffer?
    private(set) var isRunning = false

    var bpm: Int = 80 {
        didSet { restartIfRunning() }
    }

    init() {
        setupEngine()
        generateTickBuffer()
    }

    func start() {
        guard !isRunning else { return }
        ensureEngineRunning()
        scheduleTimer()
        isRunning = true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        playerNode.stop()
        isRunning = false
    }

    deinit {
        stop()
        engine.stop()
    }
}

// MARK: - Private

private extension MetronomeTick {
    func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
        } catch {
            AppLogger.pitch.error("Metronome engine failed: \(error.localizedDescription)")
        }
    }

    func generateTickBuffer() {
        let sampleRate: Double = 44100
        let duration: Double = 0.02 // 20ms click
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }
        buffer.frameLength = frameCount

        let frequency: Float = 880.0
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                let envelope = 1.0 - Float(i) / Float(frameCount) // Linear decay
                channelData[i] = sin(2.0 * .pi * frequency * t) * envelope * 0.3
            }
        }

        tickBuffer = buffer
    }

    func scheduleTimer() {
        let interval = 60.0 / Double(bpm)
        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.playTick()
        }
        // Fire immediately for the first beat
        playTick()
    }

    func playTick() {
        guard let buffer = tickBuffer else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    func ensureEngineRunning() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            AppLogger.pitch.error(
                "Metronome engine restart failed: \(error.localizedDescription)"
            )
        }
    }

    func restartIfRunning() {
        guard isRunning else { return }
        stop()
        start()
    }
}
