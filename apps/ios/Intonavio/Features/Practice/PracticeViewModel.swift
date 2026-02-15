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

    // Loop scoring
    var loopScores: [Double] = []
    var lastLoopScore: Double?
    var loopScoreImprovement: ScoreChange?
    var isShowingLoopScore = false
    private var loopMidiMin: Float?
    private var loopMidiMax: Float?

    // Phrase scoring
    var currentPhraseScore: Double?
    var currentPhraseIndex: Int?
    var totalPhrases: Int = 0
    var isShowingPhraseScore = false
    var isPhraseNewBest = false
    var isSongNewBest = false
    var songBestScore: Double = 0
    var scoreRepository: ScoreRepository?

    var transposedMidiMin: Float {
        let base = (loopState == .looping ? loopMidiMin : nil) ?? referenceStore.midiMin
        return base + Float(transposeSemitones)
    }

    var transposedMidiMax: Float {
        let base = (loopState == .looping ? loopMidiMax : nil) ?? referenceStore.midiMax
        return base + Float(transposeSemitones)
    }

    // MARK: - Song Info

    let songId: String
    let videoId: String
    var stems: [StemResponse] = []

    // MARK: - Dependencies

    let bridge = YouTubeBridge()
    let controller = YouTubePlayerController()
    let server: YouTubeLocalServer
    let audioEngine = AudioEngine()
    let stemPlayer: StemPlayer
    let stemDownloader = StemDownloader()
    private(set) var sync: VideoAudioSync?
    let sessionsViewModel: SessionsViewModel?

    // Pitch dependencies
    var pitchDetector: PitchDetector?
    let referenceStore = ReferencePitchStore()
    var scoringEngine: ScoringEngine?

    private weak var webViewRef: WKWebView?
    var loopCheckTask: Task<Void, Never>?
    var isWaitingForLoopSeek = false
    /// Stem start deferred until first YouTube time update to avoid drift.
    private var pendingStemStart = false
    var playStartTime: Date?
    var sessionSaved = false

    static let minimumPlaybackForSave: TimeInterval = 10

    var playbackDuration: TimeInterval {
        guard let start = playStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Whether this song has a full audio stem (new songs do, legacy songs don't).
    var hasFullStem: Bool { stems.contains { $0.type == .full } }

    /// Whether stem audio is active. True for all modes when FULL stem exists,
    /// or only for non-original modes on legacy songs without FULL stem.
    var isInStemMode: Bool {
        guard isStemsReady else { return false }
        return hasFullStem || audioMode != .original
    }

    init(
        songId: String,
        videoId: String,
        sessionsViewModel: SessionsViewModel? = nil
    ) {
        self.songId = songId
        self.videoId = videoId
        self.server = YouTubeLocalServer(videoId: videoId)
        self.stemPlayer = StemPlayer(engine: audioEngine)
        self.sessionsViewModel = sessionsViewModel
    }

    deinit {
        loopCheckTask?.cancel()
        server.stop()
        audioEngine.stop()
    }

    // MARK: - Setup

    func configure() {
        // Enable VP early, before any nodes are attached to the engine.
        // VP re-creates the audio graph, so it must happen first.
        // Engine starts lazily in StemPlayer.setup() or PitchDetector.start().
        try? audioEngine.prepare()

        #if os(iOS)
        audioEngine.onRouteChange = { [weak self] in
            self?.handleAudioRouteChange()
        }
        #endif

        sync = VideoAudioSync(
            controller: controller,
            stemPlayer: stemPlayer
        )
        scoringEngine = ScoringEngine(referenceStore: referenceStore)
        loadPitchDataIfAvailable()
        setupPhraseScoring()
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

        // Mute YouTube from the first play when FULL stem is available
        if hasFullStem && isStemsReady && !isMuted {
            controller.mute()
            isMuted = true
        }

        // Defer stem start until the first YouTube time update so stems
        // don't race ahead while YouTube is still buffering/starting.
        if isInStemMode {
            pendingStemStart = true
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
        isWaitingForLoopSeek = false
        pendingStemStart = false
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
        isWaitingForLoopSeek = false
        pendingStemStart = false
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
        currentTime = time
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
        guard let a = markerA else { return }
        guard currentTime > a else { return }
        markerB = currentTime
        loopState = .looping
        loopCount = 0
        loopScores = []
        lastLoopScore = nil
        loopScoreImprovement = nil

        if let range = referenceStore.midiRange(from: a, to: currentTime) {
            loopMidiMin = range.min
            loopMidiMax = range.max
        }

        scoringEngine?.reset()
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

    /// Set up a loop around a specific phrase without starting playback.
    /// Adds breathing room before the phrase start so the singer can prepare.
    func setupPhraseLoop(phraseIndex: Int) {
        guard phraseIndex >= 0, phraseIndex < referenceStore.phrases.count else { return }

        let phrase = referenceStore.phrases[phraseIndex]

        let breathingRoom: Double = 1.5
        let candidateStart = max(0, phrase.startTime - breathingRoom)
        let previousPhrase = phraseIndex > 0 ? referenceStore.phrases[phraseIndex - 1] : nil
        let loopStart: Double
        if let prev = previousPhrase, prev.endTime > candidateStart {
            loopStart = prev.endTime
        } else {
            loopStart = candidateStart
        }
        let loopEnd = phrase.endTime

        // Stop stems, pitch detection, sync, and loop checking
        isWaitingForLoopSeek = false
        pendingStemStart = false
        controller.stopTimePolling()
        stopLoopCheck()
        stopPitchDetection()
        if isInStemMode {
            stemPlayer.stop()
            sync?.stop()
        }

        // Atomic pause + seek so YouTube doesn't resume from the seek
        controller.pauseAndSeek(to: loopStart)
        currentTime = loopStart
        loopState = .paused

        markerA = loopStart
        markerB = loopEnd
        loopCount = 0
        loopScores = []
        lastLoopScore = nil
        loopScoreImprovement = nil

        if let range = referenceStore.midiRange(from: phrase.startTime, to: loopEnd) {
            loopMidiMin = range.min
            loopMidiMax = range.max
        }

        scoringEngine?.reset()
    }

    func clearLoop() {
        isWaitingForLoopSeek = false
        markerA = nil
        markerB = nil
        loopCount = 0
        loopScores = []
        lastLoopScore = nil
        loopScoreImprovement = nil
        isShowingLoopScore = false
        loopMidiMin = nil
        loopMidiMax = nil
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
            startStemsIfPending(at: time)
            checkLoopBoundary()

        case .error(let code):
            errorMessage = "YouTube error: \(code)"
            AppLogger.player.error("YouTube error code: \(code)")

        case .unknown:
            break
        }
    }

    func startStemsIfPending(at time: Double) {
        guard pendingStemStart else { return }
        pendingStemStart = false
        stemPlayer.play(from: time)
        sync?.start()
    }

    func handleAudioRouteChange() {
        guard isInStemMode else { return }
        let isPlaying = loopState == .playing || loopState == .looping

        guard isPlaying else {
            stemPlayer.applyMode(audioMode)
            return
        }

        // Stop and re-sync from current YouTube time to eliminate drift
        sync?.stop()
        stemPlayer.stop()
        stemPlayer.applyMode(audioMode)
        stemPlayer.rate = Float(playbackRate)
        stemPlayer.play(from: currentTime)
        sync?.start()
        AppLogger.audio.info("Re-synced stems after audio route change")
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
