import AVFoundation

/// Centralized AVAudioSession configuration for .playAndRecord + .measurement.
/// Both StemPlayer and PitchDetector share this session config.
/// On macOS, AVAudioEngine works without session management — this is a no-op.
enum AudioSessionManager {
    private static var isConfigured = false

    #if os(iOS)
    private static var interruptionObserver: NSObjectProtocol?
    #endif

    /// Configure the audio session for simultaneous playback and recording.
    /// Safe to call multiple times — always re-activates the session to ensure
    /// a clean state after previous teardowns.
    /// Uses `.mixWithOthers` so WKWebView (YouTube) audio is not interrupted.
    static func configure() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
        )
        try session.setPreferredIOBufferDuration(
            Double(PitchConstants.ioBufferSize) / Double(PitchConstants.sampleRate)
        )
        try session.setActive(true)
        if !isConfigured {
            observeInterruptions()
        }
        isConfigured = true
        AppLogger.pitch.info("Audio session configured for playAndRecord")
        #else
        isConfigured = true
        #endif
    }

    /// Deactivate the audio session when no longer needed.
    static func deactivate() {
        guard isConfigured else { return }

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            AppLogger.pitch.error(
                "Failed to deactivate audio session: \(error.localizedDescription)"
            )
        }
        removeInterruptionObserver()
        #endif

        isConfigured = false
    }
}

// MARK: - Interruption Handling

#if os(iOS)
private extension AudioSessionManager {
    static func observeInterruptions() {
        removeInterruptionObserver()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            handleInterruption(notification)
        }
    }

    static func removeInterruptionObserver() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    static func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            AppLogger.pitch.info("Audio session interrupted")
        case .ended:
            AppLogger.pitch.info("Audio session interruption ended")
            try? AVAudioSession.sharedInstance().setActive(true)
        @unknown default:
            break
        }
    }
}
#endif
