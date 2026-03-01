import AVFoundation
import Foundation

/// Stem player with per-stem volume control and pitch-preserving
/// rate changes via AVAudioUnitTimePitch.
///
/// Uses a shared `AudioEngine` so voice processing (AEC) can reference
/// the stem output and cancel it from the microphone input.
///
/// Audio graph (nodes owned by StemPlayer, engine owned by AudioEngine):
/// ```
/// PlayerNode(vocals)  ──┐
/// PlayerNode(other)   ──┼→ stemMixer → timePitch → mainMixer → output
/// PlayerNode(full)    ──┘
/// ```
final class StemPlayer {
    private let audioEngine: AudioEngine
    private let mixer = AVAudioMixerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var playerNodes: [StemType: AVAudioPlayerNode] = [:]
    private var audioFiles: [StemType: AVAudioFile] = [:]
    private var isSetup = false
    /// Offset added to playerTime so currentTime returns absolute file position.
    private var playbackStartOffset: Double = 0

    init(engine: AudioEngine) {
        self.audioEngine = engine
    }

    var rate: Float {
        get { timePitch.rate }
        set { timePitch.rate = newValue }
    }

    /// Processing latency introduced by the TimePitch node.
    /// Used to adjust stem time when comparing with YouTube time.
    var processingLatency: Double { timePitch.latency }

    // MARK: - Setup

    func setup(stems: [(type: StemType, url: URL)]) throws {
        teardown()

        audioEngine.attach(mixer)
        audioEngine.attach(timePitch)

        audioEngine.connect(mixer, to: timePitch, format: nil)
        audioEngine.connect(timePitch, to: audioEngine.mainMixerNode, format: nil)

        for stem in stems {
            let file = try AVAudioFile(forReading: stem.url)
            let player = AVAudioPlayerNode()

            audioEngine.attach(player)
            audioEngine.connect(player, to: mixer, format: file.processingFormat)

            playerNodes[stem.type] = player
            audioFiles[stem.type] = file
        }

        try audioEngine.start()
        isSetup = true
        AppLogger.audio.info("StemPlayer setup with \(stems.count) stems")
    }

    // MARK: - Playback

    func play(from time: Double = 0) {
        guard isSetup else { return }
        audioEngine.ensureRunning()

        // Schedule stems ahead by TimePitch processing latency so the
        // audio output aligns with the requested time after the pipeline delay.
        let compensated = time + timePitch.latency
        playbackStartOffset = compensated

        for (type, player) in playerNodes {
            guard let file = audioFiles[type] else { continue }

            let sampleRate = file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(compensated * sampleRate)
            let totalFrames = file.length
            let remainingFrames = AVAudioFrameCount(
                max(0, totalFrames - startFrame)
            )

            guard remainingFrames > 0 else { continue }

            player.stop()
            player.scheduleSegment(
                file,
                startingFrame: startFrame,
                frameCount: remainingFrames,
                at: nil
            )
            player.play()
        }
    }

    func pause() {
        for player in playerNodes.values {
            player.pause()
        }
    }

    func resume() {
        audioEngine.ensureRunning()
        for player in playerNodes.values {
            player.play()
        }
    }

    func stop() {
        for player in playerNodes.values {
            player.stop()
        }
    }

    // MARK: - Mode Control

    func setVolume(for stemType: StemType, volume: Float) {
        playerNodes[stemType]?.volume = volume
    }

    func applyMode(_ mode: AudioMode) {
        for (type, player) in playerNodes {
            switch type {
            case .full:
                player.volume = mode.hasFull ? 1.0 : 0.0
            case .vocals:
                player.volume = mode.hasVocals ? 1.0 : 0.0
            case .instrumental:
                player.volume = mode.hasInstrumental ? 1.0 : 0.0
            case .drums, .bass, .piano, .guitar, .other:
                player.volume = 0.0
            }
        }
    }

    // MARK: - Seek

    func seek(to time: Double) {
        play(from: time)
    }

    // MARK: - Current Time

    func currentTime(for stemType: StemType) -> Double? {
        guard let player = playerNodes[stemType],
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return nil
        }
        let relativeTime = Double(playerTime.sampleTime) / playerTime.sampleRate
        return playbackStartOffset + relativeTime
    }

    // MARK: - Teardown

    func teardown() {
        for player in playerNodes.values {
            player.stop()
            audioEngine.detach(player)
        }
        if isSetup {
            audioEngine.detach(mixer)
            audioEngine.detach(timePitch)
        }
        playerNodes.removeAll()
        audioFiles.removeAll()
        isSetup = false
    }

    deinit {
        teardown()
    }
}
