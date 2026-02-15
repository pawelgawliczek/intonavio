import Foundation

/// Manages exercise practice: generates reference pitch, coordinates
/// pitch detection + scoring, drives playback timer (no YouTube needed).
@Observable
final class ExercisePracticeViewModel {
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

    // MARK: - Configuration

    let exercise: ExerciseDefinition
    var tempo: Int

    // MARK: - Dependencies

    let audioEngine = AudioEngine()
    let pitchDetector: PitchDetector
    let referenceStore = ReferencePitchStore()
    private(set) var scoringEngine: ScoringEngine?
    let metronome: MetronomeTick
    let guideTone: GuideTone

    private var playbackTimer: Timer?
    private let timerInterval: TimeInterval = 0.02 // 50fps update

    var duration: Double {
        referenceStore.totalDuration
    }

    init(exercise: ExerciseDefinition) {
        self.exercise = exercise
        self.tempo = exercise.defaultTempo
        self.pitchDetector = PitchDetector(engine: audioEngine)
        self.metronome = MetronomeTick(engine: audioEngine)
        self.guideTone = GuideTone(engine: audioEngine)
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func prepare() {
        let pitchData = ExercisePitchGenerator.generate(
            notes: exercise.notes,
            tempo: tempo
        )
        referenceStore.load(from: pitchData)
        scoringEngine = ScoringEngine(referenceStore: referenceStore)
        guideTone.prepare(notes: exercise.notes, tempo: tempo)
        isPrepared = true
    }

    func play() {
        guard isPrepared, !isPlaying else { return }
        isPlaying = true
        isComplete = false

        do {
            try audioEngine.start()
        } catch {
            AppLogger.pitch.error(
                "Exercise audio engine failed: \(error.localizedDescription)"
            )
            return
        }

        metronome.bpm = tempo
        metronome.start()
        guideTone.start()

        do {
            try pitchDetector.start()
            pitchDetector.onPitchDetected = { [weak self] result in
                self?.handleDetectedPitch(result)
            }
        } catch {
            AppLogger.pitch.error(
                "Exercise pitch detection failed: \(error.localizedDescription)"
            )
        }

        startPlaybackTimer()
    }

    func pause() {
        isPlaying = false
        guideTone.stop()
        metronome.stop()
        pitchDetector.stop()
        stopPlaybackTimer()
    }

    func stop() {
        isPlaying = false
        guideTone.stop()
        metronome.stop()
        pitchDetector.stop()
        pitchDetector.onPitchDetected = nil
        stopPlaybackTimer()
        audioEngine.stop()
    }

    func restart() {
        stop()
        currentTime = 0
        detectedPoints = []
        scoringEngine?.reset()
        score = 0
        isComplete = false
        currentNoteName = nil
        centsDeviation = 0
        currentAccuracy = .unvoiced
        prepare()
    }

    func setTempo(_ newTempo: Int) {
        let wasPlaying = isPlaying
        if wasPlaying { stop() }
        tempo = newTempo
        restart()
        if wasPlaying { play() }
    }
}

// MARK: - Private

private extension ExercisePracticeViewModel {
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
        currentTime += timerInterval

        if currentTime >= duration {
            finishExercise()
            return
        }
    }

    func finishExercise() {
        stop()
        isComplete = true
        score = scoringEngine?.finalScore ?? 0
    }

    func handleDetectedPitch(_ result: PitchResult) {
        scoringEngine?.evaluate(detected: result, playbackTime: currentTime)
        score = scoringEngine?.overallScore ?? 0
        currentAccuracy = scoringEngine?.currentAccuracy ?? .unvoiced
        currentNoteName = result.noteName
        centsDeviation = result.centsDeviation

        let midi = NoteMapper.frequencyToMidi(result.frequency)
        let refFrame = referenceStore.frame(at: currentTime)
        let cents = refFrame.flatMap { ref -> Float? in
            guard ref.isVoiced, let refHz = ref.frequency else { return nil }
            return NoteMapper.centsBetween(
                detected: result.frequency,
                reference: Float(refHz)
            )
        } ?? 0

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
