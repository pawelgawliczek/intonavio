import AVFoundation

/// Plays back a best take vocal recording mixed with the instrumental stem.
/// Uses its own AVAudioEngine (not the shared practice engine) since
/// playback happens in the Progress view when practice is paused/done.
@Observable
final class BestTakePlayer {
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var isVocalMuted = false { didSet { vocalPlayer.volume = isVocalMuted ? 0 : 1 } }

    private let engine = AVAudioEngine()
    private let vocalPlayer = AVAudioPlayerNode()
    private let instrumentalPlayer = AVAudioPlayerNode()

    private var vocalFile: AVAudioFile?
    private var instrumentalFile: AVAudioFile?
    private var startOffset: TimeInterval = 0
    private var ioLatency: TimeInterval = 0
    private var displayLink: CADisplayLink?
    private var isLoaded = false

    func load(
        vocalURL: URL,
        instrumentalURL: URL,
        startOffset: TimeInterval,
        vocalSkip: TimeInterval = 0
    ) throws {
        stop()

        let vocal = try AVAudioFile(forReading: vocalURL)
        let instrumental = try AVAudioFile(forReading: instrumentalURL)

        self.vocalFile = vocal
        self.instrumentalFile = instrumental
        self.startOffset = startOffset
        self.ioLatency = vocalSkip

        engine.attach(vocalPlayer)
        engine.attach(instrumentalPlayer)

        engine.connect(vocalPlayer, to: engine.mainMixerNode, format: vocal.processingFormat)
        engine.connect(
            instrumentalPlayer,
            to: engine.mainMixerNode,
            format: instrumental.processingFormat
        )

        let vocalDuration = Double(vocal.length) / vocal.processingFormat.sampleRate - ioLatency
        let instrumentalDuration = Double(instrumental.length) / instrumental.processingFormat.sampleRate
        let instrumentalRemaining = instrumentalDuration - startOffset
        duration = min(max(0, vocalDuration), instrumentalRemaining)

        engine.prepare()
        isLoaded = true
    }

    func play() {
        guard isLoaded, !isPlaying else { return }
        guard let vocal = vocalFile, let instrumental = instrumentalFile else { return }

        do {
            try engine.start()
        } catch {
            AppLogger.audio.error("BestTakePlayer engine start failed: \(error.localizedDescription)")
            return
        }

        // Schedule vocal, skipping I/O latency frames to compensate for
        // Bluetooth + Voice Processing delay captured at recording time.
        let vocalSR = vocal.processingFormat.sampleRate
        let vocalSkipFrames = AVAudioFramePosition(ioLatency * vocalSR)
        let vocalRemaining = AVAudioFrameCount(max(0, vocal.length - vocalSkipFrames))
        if vocalRemaining > 0 {
            vocalPlayer.scheduleSegment(
                vocal,
                startingFrame: vocalSkipFrames,
                frameCount: vocalRemaining,
                at: nil
            )
        }

        // Schedule instrumental from startOffset
        let sampleRate = instrumental.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(startOffset * sampleRate)
        let remaining = AVAudioFrameCount(max(0, instrumental.length - startFrame))
        if remaining > 0 {
            instrumentalPlayer.scheduleSegment(
                instrumental,
                startingFrame: startFrame,
                frameCount: remaining,
                at: nil
            )
        }

        vocalPlayer.play()
        instrumentalPlayer.play()
        isPlaying = true
        startDisplayLink()

        AppLogger.audio.info(
            "BestTakePlayer: startOffset=\(self.startOffset) ioLatency=\(self.ioLatency) vocalSkip=\(vocalSkipFrames) instStartFrame=\(startFrame)"
        )
    }

    func pause() {
        vocalPlayer.pause()
        instrumentalPlayer.pause()
        isPlaying = false
        stopDisplayLink()
    }

    func stop() {
        stopDisplayLink()
        vocalPlayer.stop()
        instrumentalPlayer.stop()

        if isLoaded {
            engine.stop()
            engine.detach(vocalPlayer)
            engine.detach(instrumentalPlayer)
        }

        isPlaying = false
        currentTime = 0
        isLoaded = false
        vocalFile = nil
        instrumentalFile = nil
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(updateTime))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateTime() {
        guard let nodeTime = vocalPlayer.lastRenderTime,
              let playerTime = vocalPlayer.playerTime(forNodeTime: nodeTime) else {
            return
        }
        let time = Double(playerTime.sampleTime) / playerTime.sampleRate
        if time >= duration {
            pause()
            currentTime = duration
            return
        }
        currentTime = max(0, time)
    }

    deinit {
        stop()
    }
}
