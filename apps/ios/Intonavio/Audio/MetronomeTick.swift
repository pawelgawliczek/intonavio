import AVFoundation

/// Plays a metronome click at a given BPM using a short sine burst.
/// Uses a shared `AudioEngine` so it coexists with PitchDetector
/// on the same engine in exercise mode.
final class MetronomeTick {
    private let audioEngine: AudioEngine
    private var timer: Timer?
    private let playerNode = AVAudioPlayerNode()
    private var tickBuffer: AVAudioPCMBuffer?
    private(set) var isRunning = false
    private var isAttached = false

    var bpm: Int = 80 {
        didSet { restartIfRunning() }
    }

    init(engine: AudioEngine) {
        self.audioEngine = engine
    }

    func start() {
        guard !isRunning else { return }
        attachIfNeeded()
        audioEngine.ensureRunning()
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
        detach()
    }
}

// MARK: - Private

private extension MetronomeTick {
    func attachIfNeeded() {
        guard !isAttached else { return }
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.attach(playerNode)
        audioEngine.connect(
            playerNode,
            to: audioEngine.mainMixerNode,
            format: monoFormat
        )
        generateTickBuffer()
        isAttached = true
    }

    func detach() {
        guard isAttached else { return }
        audioEngine.detach(playerNode)
        isAttached = false
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

    func restartIfRunning() {
        guard isRunning else { return }
        stop()
        start()
    }
}
