import Foundation
import WebKit

/// Manages the practice session: playback state, video control, loop, speed.
@Observable
final class PracticeViewModel {
    // MARK: - Published State

    var currentTime: Double = 0
    var duration: Double = 0
    var playbackRate: Double = 1.0
    var isMuted = false
    var isPlayerReady = false
    var errorMessage: String?
    var loopState: LoopState = .idle
    var markerA: Double?
    var markerB: Double?
    var loopCount: Int = 0
    var isServerReady = false
    var audioMode: AudioMode = .original
    var isDownloadingStems = false
    var isStemsReady = false

    // Pitch
    var isPitchReady = false
    var layoutMode: PracticeLayoutMode = .lyricsFocused
    var visualizationMode: VisualizationMode = .zonesLine
    var detectedPoints: [DetectedPitchPoint] = []
    var transposeSemitones: Int = 0
    var lastDetectedMidi: Float = 0
    var lastDetectionTimestamp: TimeInterval = 0

    var transposedMidiMin: Float { referenceStore.midiMin + Float(transposeSemitones) }
    var transposedMidiMax: Float { referenceStore.midiMax + Float(transposeSemitones) }

    // MARK: - Song Info

    let songId: String
    let videoId: String
    var stems: [StemResponse] = []

    // MARK: - Dependencies

    let bridge = YouTubeBridge()
    let controller = YouTubePlayerController()
    let server: YouTubeLocalServer
    let stemPlayer = StemPlayer()
    let stemDownloader = StemDownloader()
    private(set) var sync: VideoAudioSync?
    let sessionsViewModel: SessionsViewModel?

    // Pitch dependencies
    var pitchDetector: PitchDetector?
    let referenceStore = ReferencePitchStore()
    var scoringEngine: ScoringEngine?

    private weak var webViewRef: WKWebView?
    var loopCheckTask: Task<Void, Never>?
    var playStartTime: Date?
    var sessionSaved = false

    static let minimumPlaybackForSave: TimeInterval = 10

    var playbackDuration: TimeInterval {
        guard let start = playStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var isInStemMode: Bool { audioMode != .original && isStemsReady }

    init(
        songId: String,
        videoId: String,
        sessionsViewModel: SessionsViewModel? = nil
    ) {
        self.songId = songId
        self.videoId = videoId
        self.server = YouTubeLocalServer(videoId: videoId)
        self.sessionsViewModel = sessionsViewModel
    }

    deinit {
        loopCheckTask?.cancel()
        server.stop()
    }

    // MARK: - Setup

    func configure() {
        // Configure audio session early so it's active before YouTube loads.
        // This prevents session interruptions when PitchDetector starts later.
        try? AudioSessionManager.configure()

        sync = VideoAudioSync(
            controller: controller,
            stemPlayer: stemPlayer
        )
        scoringEngine = ScoringEngine(referenceStore: referenceStore)
        loadPitchDataIfAvailable()
        bridge.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
        server.onReady = { [weak self] in
            guard let self else { return }
            self.isServerReady = true
            AppLogger.player.info("Server ready on \(self.server.origin)")
            self.loadCurrentVideo()
        }
        server.start()
    }

    func onWebViewReady(_ webView: WKWebView) {
        controller.attach(webView)
        webViewRef = webView

        if server.isReady {
            loadCurrentVideo()
        }
    }

    // MARK: - Playback Controls

    func play() {
        controller.play()
        controller.startTimePolling(intervalMs: 50)
        playStartTime = playStartTime ?? Date()

        if isInStemMode {
            stemPlayer.play(from: currentTime)
            sync?.start()
        }

        startPitchDetection()

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
        stopPitchDetection()

        if isInStemMode {
            stemPlayer.pause()
            sync?.stop()
        }
    }

    func stop() {
        controller.stop()
        controller.stopTimePolling()
        loopState = .idle
        stopLoopCheck()
        clearLoop()
        stopPitchDetection()

        if isInStemMode {
            stemPlayer.stop()
            sync?.stop()
        }
    }

    func seek(to time: Double) {
        controller.seek(to: time)
        if isInStemMode {
            stemPlayer.seek(to: time)
        }
    }

    func setSpeed(_ rate: Double) {
        playbackRate = rate
        controller.setPlaybackRate(rate)
        if isInStemMode {
            stemPlayer.rate = Float(rate)
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

private extension PracticeViewModel {
    func handleEvent(_ event: YouTubeEvent) {
        switch event {
        case .ready(let dur):
            duration = dur
            isPlayerReady = true
            controller.markReady(duration: dur)

        case .stateChange(let state):
            handleStateChange(state)

        case .timeUpdate(let time, _):
            currentTime = time
            controller.updateTime(time)
            checkLoopBoundary()

        case .error(let code):
            errorMessage = "YouTube error: \(code)"
            AppLogger.player.error("YouTube error code: \(code)")

        case .unknown:
            break
        }
    }

    func handleStateChange(_ state: YouTubePlayerState) {
        if state == .ended {
            if loopState == .looping, let a = markerA {
                controller.seek(to: a)
                controller.play()
                if isInStemMode {
                    stemPlayer.seek(to: a)
                }
                loopCount += 1
            } else {
                loopState = .idle
                controller.stopTimePolling()
                stopLoopCheck()
                if isInStemMode {
                    stemPlayer.stop()
                    sync?.stop()
                }
            }
        }
    }

    func loadCurrentVideo() {
        guard let wk = webViewRef, server.isReady else { return }
        let url = server.playerURL
        AppLogger.player.debug("Loading player from \(url)")
        wk.load(URLRequest(url: url))
    }
}
