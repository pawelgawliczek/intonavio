import AVFoundation
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

    // Offline mode
    let isOffline: Bool
    private var offlineTimer: Timer?
    private let offlineTimerInterval: TimeInterval = 0.02

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
    var isSongScoreInvalidated = false
    var isSongScoreSaved = false
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

    // Lyrics
    let lyricsProvider = LyricsProvider()

    // Best take recording
    var streamingRecorder: StreamingRecorder?
    var bestTakeStartTime: Double = 0
    var bestTakeTempURL: URL?
    /// Deferred until first YouTube time update, like stems.
    var pendingBestTakeStart = false

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
        sessionsViewModel: SessionsViewModel? = nil,
        isOffline: Bool = false
    ) {
        self.songId = songId
        self.videoId = videoId
        self.isOffline = isOffline
        self.server = YouTubeLocalServer(videoId: videoId)
        self.stemPlayer = StemPlayer(engine: audioEngine)
        self.sessionsViewModel = sessionsViewModel
    }

    deinit {
        loopCheckTask?.cancel()
        offlineTimer?.invalidate()
        if !isOffline { server.stop() }
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

        scoringEngine = ScoringEngine(referenceStore: referenceStore)
        loadPitchDataIfAvailable()
        setupPhraseScoring()

        if isOffline {
            // Offline: no YouTube, stems are the master clock.
            // Duration is set after stems are loaded.
            isPlayerReady = true
            return
        }

        sync = VideoAudioSync(
            controller: controller,
            stemPlayer: stemPlayer
        )
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
        playStartTime = playStartTime ?? Date()

        if isOffline {
            stemPlayer.play(from: currentTime)
            startOfflineTimer()
            startPitchDetection()
            pendingBestTakeStart = streamingRecorder == nil && !isSongScoreInvalidated
            if pendingBestTakeStart {
                pendingBestTakeStart = false
                startBestTakeRecording()
            }
            if markerA != nil, markerB != nil {
                loopState = .looping
                startLoopCheck()
            } else {
                loopState = .playing
            }
            return
        }

        controller.play()
        controller.startTimePolling(intervalMs: 50)

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
        pendingBestTakeStart = streamingRecorder == nil && !isSongScoreInvalidated

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
        pendingBestTakeStart = false
        loopState = .paused
        stopLoopCheck()
        stopPitchDetection()

        if isOffline {
            stemPlayer.pause()
            stopOfflineTimer()
            return
        }

        controller.pause()
        controller.stopTimePolling()

        if isInStemMode {
            stemPlayer.pause()
            sync?.stop()
        }
    }

    func stop() {
        isWaitingForLoopSeek = false
        pendingStemStart = false
        loopState = .idle
        stopLoopCheck()
        clearLoop()
        stopPitchDetection()

        if isOffline {
            stemPlayer.stop()
            stopOfflineTimer()
            return
        }

        controller.stop()
        controller.stopTimePolling()

        if isInStemMode {
            stemPlayer.stop()
            sync?.stop()
        }
    }

    func seek(to time: Double) {
        currentTime = time
        detectedPoints.removeAll { $0.time >= time }
        isSongScoreInvalidated = true
        invalidateBestTakeRecording()

        if isOffline {
            stemPlayer.seek(to: time)
            return
        }

        controller.seek(to: time)
        if isInStemMode {
            stemPlayer.seek(to: time)
        }
    }

    func setSpeed(_ rate: Double) {
        playbackRate = rate
        stemPlayer.rate = Float(rate)
        if !isOffline {
            controller.setPlaybackRate(rate)
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
        isSongScoreInvalidated = true
        invalidateBestTakeRecording()

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
        isSongScoreInvalidated = true

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
        stopLoopCheck()
        stopPitchDetection()

        if isOffline {
            stemPlayer.stop()
            stopOfflineTimer()
        } else {
            controller.stopTimePolling()
            if isInStemMode {
                stemPlayer.stop()
                sync?.stop()
            }
            controller.pauseAndSeek(to: loopStart)
        }

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

// MARK: - Offline Timer

extension PracticeViewModel {
    func startOfflineTimer() {
        stopOfflineTimer()
        offlineTimer = Timer.scheduledTimer(
            withTimeInterval: offlineTimerInterval,
            repeats: true
        ) { [weak self] _ in
            self?.offlineTick()
        }
    }

    func stopOfflineTimer() {
        offlineTimer?.invalidate()
        offlineTimer = nil
    }

    /// Set duration from loaded stem audio files.
    func setDurationFromStems() {
        // Use the FULL stem if available, otherwise any stem
        let preferred: [StemType] = [.full, .vocals, .instrumental]
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        let stemDir = caches
            .appendingPathComponent("stems", isDirectory: true)
            .appendingPathComponent(songId, isDirectory: true)

        for type in preferred {
            guard stems.contains(where: { $0.type == type }) else { continue }
            let url = stemDir.appendingPathComponent(
                "\(type.rawValue.lowercased()).mp3"
            )
            guard let file = try? AVAudioFile(forReading: url) else { continue }
            duration = Double(file.length) / file.processingFormat.sampleRate
            AppLogger.audio.info("Offline duration from \(type.rawValue): \(self.duration)s")
            return
        }
    }

    private func offlineTick() {
        guard let time = stemPlayer.currentTime(for: .full)
            ?? stemPlayer.currentTime(for: .vocals)
            ?? stemPlayer.currentTime(for: .instrumental) else {
            return
        }

        // Adjust for TimePitch latency (same as playbackStartOffset in StemPlayer)
        let adjusted = time - stemPlayer.processingLatency
        currentTime = max(0, adjusted)

        checkLoopBoundary()

        // Handle end of song
        if currentTime >= duration - 0.1 {
            stop()
            loopState = .idle
            saveSongScore()
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
        if pendingStemStart {
            pendingStemStart = false
            stemPlayer.play(from: time)
            sync?.start()
        }

        if pendingBestTakeStart {
            pendingBestTakeStart = false
            startBestTakeRecording()
        }
    }

    func handleAudioRouteChange() {
        let isPlaying = loopState == .playing || loopState == .looping

        if isOffline {
            guard isPlaying else {
                stemPlayer.applyMode(audioMode)
                return
            }
            stemPlayer.stop()
            stemPlayer.applyMode(audioMode)
            stemPlayer.rate = Float(playbackRate)
            stemPlayer.play(from: currentTime)
            AppLogger.audio.info("Re-synced stems after route change (offline)")
            return
        }

        guard isInStemMode else { return }

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
                stopPitchDetection()
                saveSongScore()
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
