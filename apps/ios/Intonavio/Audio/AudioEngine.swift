import AVFoundation
#if os(macOS)
import CoreAudio
#endif

/// Shared AVAudioEngine wrapper that owns a single engine instance.
/// Enables voice processing (AEC) on the input node so the microphone
/// can cancel stem audio playing through the speakers.
///
/// Audio graph:
/// ```
/// Mic → inputNode (VP/AEC) ── tap ──→ PitchDetector ring buffer
///
/// PlayerNode(vocals)  ──┐
/// PlayerNode(other)   ──┼→ stemMixer → timePitch → mainMixer → output
/// PlayerNode(full)    ──┘
/// ```
final class AudioEngine {
    let engine = AVAudioEngine()
    private(set) var isRunning = false
    private var isPrepared = false

    /// Fan-out single input tap to multiple consumers (pitch detection + recording).
    private(set) lazy var inputTapRouter = InputTapRouter(engine: self)

    /// Whether the current audio route uses Bluetooth output (e.g. AirPods).
    /// When true, voice processing (AEC) is skipped and mic gain is boosted.
    private(set) var isBluetoothRoute = false

    #if os(iOS)
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    /// Called on the main queue when the audio output route changes
    /// (e.g. AirPods connected/disconnected). Receivers should re-sync
    /// playback to avoid stem drift.
    var onRouteChange: (() -> Void)?
    #endif

    // MARK: - Lifecycle

    /// Configure audio session and enable voice processing.
    /// Must be called before attaching nodes — VP re-creates the audio graph.
    /// Safe to call multiple times (idempotent).
    func prepare() throws {
        guard !isPrepared else { return }

        #if os(iOS)
        try AudioSessionManager.configure()
        isBluetoothRoute = detectBluetoothRoute()
        #endif

        let inputNode = engine.inputNode

        #if os(macOS)
        // macOS VP requires matching input/output hardware sample rates.
        // Use CoreAudio HAL to set the default output device rate to match input.
        matchOutputSampleRateToInput()
        #endif

        // Always enable VP — toggling it disrupts the audio graph and resets
        // mixer connections. With Bluetooth (no speaker bleed), AEC is a no-op
        // but harmless. PitchDetector compensates with a mic gain boost instead.
        if !inputNode.isVoiceProcessingEnabled {
            try inputNode.setVoiceProcessingEnabled(true)
            AppLogger.audio.info("Voice processing (AEC) enabled on shared engine")
        }

        if isBluetoothRoute {
            AppLogger.audio.info("Bluetooth route detected — mic gain boost active")
        }

        isPrepared = true
    }

    /// Start the engine. Calls prepare() first if not already done.
    /// Attach nodes between prepare() and start() to avoid VP disconnecting them.
    func start() throws {
        guard !isRunning else { return }
        try prepare()

        engine.prepare()
        try engine.start()
        isRunning = true

        #if os(iOS)
        observeInterruptions()
        observeRouteChanges()
        #endif

        AppLogger.audio.info("AudioEngine started")
    }

    func stop() {
        guard isRunning else { return }

        #if os(iOS)
        removeInterruptionObserver()
        removeRouteChangeObserver()
        #endif

        engine.stop()
        isRunning = false
        AppLogger.audio.info("AudioEngine stopped")
    }

    /// Full shutdown — stops engine and deactivates audio session.
    /// Call when the practice session ends, not for temporary pauses.
    func shutdown() {
        stop()
        #if os(iOS)
        AudioSessionManager.deactivate()
        #endif
        isPrepared = false
    }

    // MARK: - Node Management

    func attach(_ node: AVAudioNode) {
        engine.attach(node)
    }

    func detach(_ node: AVAudioNode) {
        engine.detach(node)
    }

    func connect(
        _ from: AVAudioNode,
        to: AVAudioNode,
        format: AVAudioFormat?
    ) {
        engine.connect(from, to: to, format: format)
    }

    // MARK: - Input Tap (Microphone)

    /// Install a tap on the input node for pitch detection.
    /// Read `inputFormat` after calling `start()` — VP may change it.
    func installInputTap(
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void
    ) {
        engine.inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: format,
            block: block
        )
    }

    func removeInputTap() {
        engine.inputNode.removeTap(onBus: 0)
    }

    // MARK: - Accessors

    /// Input format — read AFTER prepare() so VP format is applied.
    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    var mainMixerNode: AVAudioMixerNode {
        engine.mainMixerNode
    }

    // MARK: - Engine Recovery

    func ensureRunning() {
        guard isRunning, !engine.isRunning else { return }
        do {
            try engine.start()
            AppLogger.audio.info("AudioEngine restarted after interruption")
        } catch {
            AppLogger.audio.error(
                "Failed to restart engine: \(error.localizedDescription)"
            )
        }
    }

    deinit {
        stop()
    }
}

// MARK: - Bluetooth Route Detection (iOS)

#if os(iOS)
extension AudioEngine {
    func detectBluetoothRoute() -> Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains { output in
            output.portType == .bluetoothA2DP
                || output.portType == .bluetoothLE
                || output.portType == .bluetoothHFP
        }
    }
}
#endif

// MARK: - Interruption & Route Change Handling (iOS)

#if os(iOS)
private extension AudioEngine {
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

        switch type {
        case .began:
            AppLogger.audio.info("Audio session interrupted")
        case .ended:
            AppLogger.audio.info("Audio session interruption ended")
            try? AVAudioSession.sharedInstance().setActive(true)
            ensureRunning()
        @unknown default:
            break
        }
    }

    func observeRouteChanges() {
        removeRouteChangeObserver()
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    func removeRouteChangeObserver() {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
    }

    func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            AppLogger.audio.info("Audio route changed: \(reason.rawValue)")
            isBluetoothRoute = detectBluetoothRoute()
            AppLogger.audio.info("Bluetooth route: \(self.isBluetoothRoute)")
            ensureRunning()
            onRouteChange?()
        default:
            break
        }
    }
}
#endif

// MARK: - macOS Sample Rate Matching

#if os(macOS)
private extension AudioEngine {
    /// Set the default output device's sample rate to match the default input
    /// device. VP creates an aggregate device and requires both sides to agree.
    func matchOutputSampleRateToInput() {
        guard let inputRate = hardwareSampleRate(forDefaultDevice: true),
              let outputRate = hardwareSampleRate(forDefaultDevice: false),
              inputRate != outputRate, inputRate > 0
        else { return }

        let outputID = defaultAudioDeviceID(input: false)
        guard outputID != kAudioObjectUnknown else { return }

        var rate = inputRate
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            outputID, &address, 0, nil,
            UInt32(MemoryLayout<Float64>.size), &rate
        )
        if status == noErr {
            AppLogger.audio.info(
                "Set output device sample rate from \(outputRate) to \(inputRate)"
            )
        } else {
            AppLogger.audio.error(
                "Failed to set output sample rate: \(status)"
            )
        }
    }

    func defaultAudioDeviceID(input: Bool) -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: input
                ? kAudioHardwarePropertyDefaultInputDevice
                : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }

    func hardwareSampleRate(forDefaultDevice input: Bool) -> Float64? {
        let deviceID = defaultAudioDeviceID(input: input)
        guard deviceID != kAudioObjectUnknown else { return nil }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &rate
        )
        return status == noErr ? rate : nil
    }
}
#endif
