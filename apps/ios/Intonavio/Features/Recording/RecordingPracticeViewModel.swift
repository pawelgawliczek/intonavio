import AVFoundation

/// Manages practice against a recording: plays back the recorded audio,
/// detects the singer's voice, and scores against the analyzed pitch data.
/// Follows the same pattern as ExercisePracticeViewModel.
@Observable
final class RecordingPracticeViewModel {
    // MARK: - State

    var currentTime: Double = 0
    var isPlaying = false
    var isPrepared = false
    var score: Double = 0
    var isComplete = false
    var currentNoteName: String?
    var centsDeviation: Float = 0
    var currentAccuracy: PitchAccuracy = .unvoiced
    var visualizationMode: VisualizationMode = .zonesLine
    var detectedPoints: [DetectedPitchPoint] = []

    // MARK: - Edit & Refine

    var transposeSemitones: Int = 0
    var playbackRate: Double = 1.0
    var loopStart: Double?
    var loopEnd: Double?
    var isLooping: Bool { loopStart != nil }

    // MARK: - Dependencies

    let audioEngine = AudioEngine()
    let pitchDetector: PitchDetector
    let referenceStore = ReferencePitchStore()
    private(set) var scoringEngine: ScoringEngine?

    private var playerNode: AVAudioPlayerNode?
    private var timePitchNode: AVAudioUnitTimePitch?
    private var playbackTimer: Timer?
    private let timerInterval: TimeInterval = 0.02

    let recording: Recording
    private var audioFileURL: URL?
    private var lastDetectedMidi: Float = 0
    private var lastDetectionTimestamp: TimeInterval = 0

    var duration: Double { referenceStore.totalDuration }

    init(recording: Recording) {
        self.recording = recording
        self.pitchDetector = PitchDetector(engine: audioEngine)
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func prepare() {
        guard let pitchData = decodePitchData() else { return }

        referenceStore.load(from: pitchData)
        scoringEngine = ScoringEngine(referenceStore: referenceStore)
        audioFileURL = resolveAudioFile()

        if let url = audioFileURL {
            setupPlayerNode(url: url)
        }

        isPrepared = true
    }

    func play() {
        guard isPrepared, !isPlaying else { return }
        isPlaying = true
        isComplete = false

        do {
            try audioEngine.start()
        } catch {
            AppLogger.audio.error(
                "Recording practice engine failed: \(error.localizedDescription)"
            )
            return
        }

        startAudioPlayback()

        do {
            try pitchDetector.start()
            pitchDetector.onPitchDetected = { [weak self] result in
                self?.handleDetectedPitch(result)
            }
        } catch {
            AppLogger.pitch.error(
                "Recording pitch detection failed: \(error.localizedDescription)"
            )
        }

        startPlaybackTimer()
    }

    func pause() {
        isPlaying = false
        playerNode?.pause()
        pitchDetector.stop()
        stopPlaybackTimer()
    }

    func stop() {
        isPlaying = false
        playerNode?.stop()
        pitchDetector.stop()
        pitchDetector.onPitchDetected = nil
        stopPlaybackTimer()
        audioEngine.stop()
    }

    func restart() {
        stop()
        currentTime = loopStart ?? 0
        detectedPoints = []
        scoringEngine?.reset()
        score = 0
        isComplete = false
        currentNoteName = nil
        centsDeviation = 0
        currentAccuracy = .unvoiced
        prepare()
    }

    // MARK: - Edit & Refine

    func setTranspose(_ semitones: Int) {
        transposeSemitones = semitones
        scoringEngine?.transposeSemitones = semitones
    }

    func setSpeed(_ rate: Double) {
        playbackRate = rate
        timePitchNode?.rate = Float(rate)
    }

    func setLoop(start: Double, end: Double) {
        loopStart = start
        loopEnd = end
    }

    func clearLoop() {
        loopStart = nil
        loopEnd = nil
    }

    func seekTo(_ time: Double) {
        currentTime = time
        detectedPoints = []
        scoringEngine?.reset()
        score = 0
        scheduleAudioFrom(time: time)
    }
}

// MARK: - Private

private extension RecordingPracticeViewModel {
    func decodePitchData() -> ReferencePitchData? {
        do {
            let frames = try JSONDecoder().decode(
                [ReferencePitchFrame].self, from: recording.pitchFrames
            )
            let hopDuration = Double(PitchConstants.hopSize)
                / Double(PitchConstants.sampleRate)
            return ReferencePitchData(
                songId: nil,
                sampleRate: Int(PitchConstants.sampleRate),
                hopSize: PitchConstants.hopSize,
                frameCount: frames.count,
                hopDuration: hopDuration,
                frames: frames,
                phrases: []
            )
        } catch {
            AppLogger.audio.error(
                "Failed to decode pitch frames: \(error.localizedDescription)"
            )
            return nil
        }
    }

    func resolveAudioFile() -> URL? {
        let docsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0]
        let fileName = recording.audioFileName
        let url = docsURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLogger.audio.error("Audio file not found: \(fileName)")
            return nil
        }
        return url
    }

    func setupPlayerNode(url: URL) {
        let node = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        audioEngine.attach(node)
        audioEngine.attach(timePitch)

        guard let audioFile = try? AVAudioFile(forReading: url) else {
            AppLogger.audio.error("Cannot read audio file: \(url.lastPathComponent)")
            return
        }

        audioEngine.connect(
            node, to: timePitch, format: audioFile.processingFormat
        )
        audioEngine.connect(
            timePitch, to: audioEngine.mainMixerNode,
            format: audioFile.processingFormat
        )

        timePitch.rate = Float(playbackRate)
        playerNode = node
        timePitchNode = timePitch
    }

    func startAudioPlayback() {
        let startTime = loopStart ?? 0
        if startTime > 0 {
            scheduleAudioFrom(time: startTime)
        } else {
            guard let node = playerNode, let url = audioFileURL,
                  let file = try? AVAudioFile(forReading: url) else { return }
            node.stop()
            node.scheduleFile(file, at: nil)
            node.play()
        }
    }

    func scheduleAudioFrom(time: Double) {
        guard let node = playerNode, let url = audioFileURL,
              let file = try? AVAudioFile(forReading: url) else { return }

        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let endTime = loopEnd ?? (Double(file.length) / sampleRate)
        let endFrame = min(
            AVAudioFramePosition(endTime * sampleRate), file.length
        )
        let frameCount = AVAudioFrameCount(max(0, endFrame - startFrame))
        guard frameCount > 0 else { return }

        node.stop()
        node.scheduleSegment(
            file, startingFrame: startFrame,
            frameCount: frameCount, at: nil
        )
        node.play()
    }

    func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(
            withTimeInterval: timerInterval,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func tick() {
        currentTime += timerInterval * playbackRate

        if let end = loopEnd, currentTime >= end {
            currentTime = loopStart ?? 0
            detectedPoints = []
            scheduleAudioFrom(time: currentTime)
            return
        }

        if currentTime >= duration {
            finishPractice()
        }
    }

    func finishPractice() {
        stop()
        isComplete = true
        score = scoringEngine?.finalScore ?? 0
    }

    func handleDetectedPitch(_ result: PitchResult) {
        let midi = NoteMapper.frequencyToMidi(result.frequency)
        let now = result.timestamp

        // MIDI jump filter — reject points that jump >12 semitones within 50ms
        if lastDetectionTimestamp > 0 {
            let timeDelta = now - lastDetectionTimestamp
            let midiDelta = abs(midi - lastDetectedMidi)
            if timeDelta < PitchConstants.jumpTimeWindow,
               midiDelta > PitchConstants.maxMidiJump {
                return
            }
        }

        lastDetectedMidi = midi
        lastDetectionTimestamp = now

        scoringEngine?.evaluate(detected: result, playbackTime: currentTime)
        score = scoringEngine?.overallScore ?? 0
        currentAccuracy = scoringEngine?.currentAccuracy ?? .unvoiced
        currentNoteName = result.noteName
        centsDeviation = result.centsDeviation

        let rawRefHz = referenceStore.frame(at: currentTime)?.frequency
            ?? Double(result.frequency)
        let adjustedRefHz = rawRefHz * pow(2.0, Double(transposeSemitones) / 12.0)
        let cents = NoteMapper.centsBetween(
            detected: result.frequency,
            reference: Float(adjustedRefHz)
        )
        let accuracy = PitchAccuracy.classify(cents: cents)

        detectedPoints.append(DetectedPitchPoint(
            time: currentTime,
            midi: midi,
            accuracy: accuracy,
            cents: cents
        ))

        if detectedPoints.count > 6000 {
            detectedPoints.removeFirst(1000)
        }
    }
}
