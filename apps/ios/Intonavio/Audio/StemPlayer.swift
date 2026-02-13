import AVFoundation
import Foundation

/// AVAudioEngine-based stem player with per-stem volume control
/// and pitch-preserving rate changes via AVAudioUnitTimePitch.
///
/// Audio graph:
/// ```
/// PlayerNode(vocals)  --\
/// PlayerNode(other)   ----> MixerNode --> TimePitch --> mainMixer --> output
/// ```
final class StemPlayer {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var playerNodes: [StemType: AVAudioPlayerNode] = [:]
    private var audioFiles: [StemType: AVAudioFile] = [:]
    private var isSetup = false
    private var interruptionObserver: NSObjectProtocol?

    var rate: Float {
        get { timePitch.rate }
        set { timePitch.rate = newValue }
    }

    // MARK: - Setup

    func setup(stems: [(type: StemType, url: URL)]) throws {
        teardown()

        engine.attach(mixer)
        engine.attach(timePitch)

        engine.connect(mixer, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)

        for stem in stems {
            let file = try AVAudioFile(forReading: stem.url)
            let player = AVAudioPlayerNode()

            engine.attach(player)
            engine.connect(player, to: mixer, format: file.processingFormat)

            playerNodes[stem.type] = player
            audioFiles[stem.type] = file
        }

        try engine.start()
        isSetup = true
        observeInterruptions()
        AppLogger.audio.info("StemPlayer setup with \(stems.count) stems")
    }

    // MARK: - Playback

    func play(from time: Double = 0) {
        guard isSetup else { return }
        ensureEngineRunning()

        for (type, player) in playerNodes {
            guard let file = audioFiles[type] else { continue }

            let sampleRate = file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(time * sampleRate)
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
        ensureEngineRunning()
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
            case .vocals:
                player.volume = mode.hasVocals ? 1.0 : 0.0
            default:
                player.volume = mode.hasInstrumental ? 1.0 : 0.0
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
        return Double(playerTime.sampleTime) / playerTime.sampleRate
    }

    // MARK: - Teardown

    func teardown() {
        removeInterruptionObserver()
        engine.stop()
        for player in playerNodes.values {
            player.stop()
            engine.detach(player)
        }
        if isSetup {
            engine.detach(mixer)
            engine.detach(timePitch)
        }
        playerNodes.removeAll()
        audioFiles.removeAll()
        isSetup = false
    }

    deinit {
        teardown()
    }
}

// MARK: - Engine Recovery

private extension StemPlayer {
    func ensureEngineRunning() {
        guard isSetup, !engine.isRunning else { return }
        do {
            try engine.start()
            AppLogger.audio.info("AVAudioEngine restarted after stop")
        } catch {
            AppLogger.audio.error(
                "Failed to restart engine: \(error.localizedDescription)"
            )
        }
    }

    func observeInterruptions() {
        removeInterruptionObserver()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }

    func removeInterruptionObserver() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        if type == .ended {
            ensureEngineRunning()
        }
    }
}
