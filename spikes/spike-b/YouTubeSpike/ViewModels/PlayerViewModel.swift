import SwiftUI
import WebKit

/// Loop state machine per docs/07-youtube-looping.md:
/// Idle → Playing → SettingA → SettingAB → Looping
enum LoopState: String {
    case idle
    case playing
    case settingA
    case settingAB
    case looping
    case paused
}

/// Bridges YouTube player controls and loop logic to SwiftUI.
@Observable
final class PlayerViewModel {
    // MARK: - Published State

    var videoId: String = "uBJdwRPO1QE"
    var loopState: LoopState = .idle
    var currentTime: Double = 0
    var duration: Double = 0
    var playbackRate: Double = 1.0
    var isMuted: Bool = false
    var isPlayerReady = false
    var errorMessage: String?

    var markerA: Double?
    var markerB: Double?

    var bridgeLatencyAvg: Double = 0
    var seekPrecisionLast: Double = 0
    var loopCount: Int = 0
    var serverReady = false

    // MARK: - Dependencies

    let bridge = YouTubeBridge()
    let controller = YouTubePlayerController()
    let seekLogger = SeekPrecisionLogger()
    let server: YouTubeLocalServer

    init() {
        server = YouTubeLocalServer(videoId: "uBJdwRPO1QE")
    }

    // MARK: - Private

    private var loopCheckTimer: Timer?
    private var bridgeLatencies: [Double] = []
    private weak var webViewRef: WKWebView?

    // MARK: - Setup

    func onWebViewReady(_ webView: Any) {
        guard let wk = webView as? WKWebView else { return }
        controller.attach(wk)
        webViewRef = wk

        // If server is already ready, load immediately
        if server.isReady {
            loadCurrentVideo()
        }
    }

    func configure() {
        bridge.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
        server.onReady = { [weak self] in
            guard let self else { return }
            self.serverReady = true
            print("[VM] Server ready on \(self.server.origin)")
            self.loadCurrentVideo()
        }
        server.start()
    }

    private func loadCurrentVideo() {
        guard let wk = webViewRef, server.isReady else { return }
        let url = server.playerURL
        print("[VM] Loading player from \(url)")
        wk.load(URLRequest(url: url))
    }

    // MARK: - Playback Controls

    func play() {
        controller.play()
        controller.startTimePolling(intervalMs: 50)
        if markerA != nil, markerB != nil {
            loopState = .looping
            startLoopCheck()
        } else {
            loopState = .playing
        }
    }

    func pause() {
        controller.pause()
        controller.stopTimePolling()
        loopState = .paused
        stopLoopCheck()
    }

    func stop() {
        controller.stop()
        controller.stopTimePolling()
        loopState = .idle
        stopLoopCheck()
        clearLoop()
    }

    func seek(to time: Double) {
        let start = CFAbsoluteTimeGetCurrent()
        controller.seek(to: time)

        // Measure seek precision after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            [weak self] in
            self?.controller.getCurrentTime { actual in
                let precision = abs(actual - time) * 1000.0
                self?.seekPrecisionLast = precision
                self?.seekLogger.record(
                    requested: time,
                    actual: actual,
                    latencyMs: (CFAbsoluteTimeGetCurrent()
                                - start) * 1000.0
                )
            }
        }
    }

    func setSpeed(_ rate: Double) {
        playbackRate = rate
        controller.setPlaybackRate(rate)
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            controller.mute()
        } else {
            controller.unmute()
        }
    }

    // MARK: - Loop Controls

    func setMarkerA() {
        markerA = currentTime
        markerB = nil
        loopState = .settingA
    }

    func setMarkerB() {
        guard markerA != nil else { return }
        guard currentTime > (markerA ?? 0) else { return }
        markerB = currentTime
        loopState = .looping
        loopCount = 0
        startLoopCheck()
    }

    func setMarkerAPosition(_ time: Double) {
        let upper = markerB ?? duration
        markerA = max(0, min(time, upper))
    }

    func setMarkerBPosition(_ time: Double) {
        let lower = markerA ?? 0
        markerB = max(lower, min(time, duration))
    }

    func clearLoop() {
        markerA = nil
        markerB = nil
        loopCount = 0
        stopLoopCheck()
        if loopState == .looping || loopState == .settingA {
            loopState = .playing
        }
    }
}

// MARK: - Event Handling

private extension PlayerViewModel {
    func handleEvent(_ event: YouTubeEvent) {
        switch event {
        case .ready(let dur):
            duration = dur
            isPlayerReady = true

        case .stateChange(let state):
            handleStateChange(state)

        case .timeUpdate(let time, let jsTs):
            currentTime = time
            trackBridgeLatency(jsTimestamp: jsTs)
            checkLoopBoundary()

        case .error(let code):
            errorMessage = "YouTube error: \(code)"

        case .unknown:
            break
        }
    }

    func handleStateChange(_ state: YouTubePlayerState) {
        switch state {
        case .ended:
            if loopState == .looping, let a = markerA {
                controller.seek(to: a)
                controller.play()
                loopCount += 1
            } else {
                loopState = .idle
                controller.stopTimePolling()
                stopLoopCheck()
            }
        default:
            break
        }
    }

    func trackBridgeLatency(jsTimestamp: Double) {
        let now = Date().timeIntervalSince1970 * 1000.0
        let latency = now - jsTimestamp
        bridgeLatencies.append(latency)
        if bridgeLatencies.count > 100 {
            bridgeLatencies.removeFirst()
        }
        bridgeLatencyAvg = bridgeLatencies.reduce(0, +)
            / Double(bridgeLatencies.count)
    }
}

// MARK: - Loop Logic

private extension PlayerViewModel {
    func startLoopCheck() {
        stopLoopCheck()
        // 20Hz polling as specified in the plan
        loopCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 0.05,
            repeats: true
        ) { [weak self] _ in
            self?.checkLoopBoundary()
        }
    }

    func stopLoopCheck() {
        loopCheckTimer?.invalidate()
        loopCheckTimer = nil
    }

    func checkLoopBoundary() {
        guard loopState == .looping,
              let a = markerA,
              let b = markerB else {
            return
        }

        // Seek back to A when approaching B (50ms buffer)
        if currentTime >= b - 0.05 {
            controller.seek(to: a)
            loopCount += 1
        }
    }
}
