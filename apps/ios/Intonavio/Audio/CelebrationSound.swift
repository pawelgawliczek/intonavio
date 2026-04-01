import AVFoundation

/// Plays short celebratory SoundFont melodies for score milestones.
/// Reuses the existing `GeneralUser-GS.sf2` and shares the app's `AudioEngine`.
final class CelebrationSound {
    private let audioEngine: AudioEngine
    private let sampler = AVAudioUnitSampler()
    private var isAttached = false
    private var noteTimers: [Timer] = []

    init(engine: AudioEngine) {
        self.audioEngine = engine
    }

    // MARK: - Public API

    /// Glockenspiel 2-note ascending chime (C5 → E5).
    func playPhraseBest() {
        loadAndPlay(program: 9, notes: [
            (midi: 72, velocity: 70, delay: 0.0),
            (midi: 76, velocity: 75, delay: 0.12),
        ], noteDuration: 0.3)
    }

    /// Celesta 4-note ascending arpeggio (C5 → E5 → G5 → C6).
    func playSongBest() {
        loadAndPlay(program: 8, notes: [
            (midi: 72, velocity: 85, delay: 0.0),
            (midi: 76, velocity: 90, delay: 0.1),
            (midi: 79, velocity: 90, delay: 0.2),
            (midi: 84, velocity: 95, delay: 0.35),
        ], noteDuration: 0.5)
    }

    /// Vibraphone single ascending note.
    func playLoopImprovement() {
        loadAndPlay(program: 11, notes: [
            (midi: 74, velocity: 60, delay: 0.0),
        ], noteDuration: 0.25)
    }

    func cancelAll() {
        noteTimers.forEach { $0.invalidate() }
        noteTimers.removeAll()
    }

    deinit {
        cancelAll()
        detach()
    }
}

// MARK: - Private

private extension CelebrationSound {
    struct NoteSpec {
        let midi: UInt8
        let velocity: UInt8
        let delay: TimeInterval
    }

    func loadAndPlay(
        program: UInt8,
        notes: [(midi: UInt8, velocity: UInt8, delay: TimeInterval)],
        noteDuration: TimeInterval
    ) {
        attachIfNeeded()
        guard let url = Bundle.main.url(
            forResource: "GeneralUser-GS", withExtension: "sf2"
        ) else {
            AppLogger.audio.error("CelebrationSound: SoundFont not found")
            return
        }

        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: program,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
        } catch {
            AppLogger.audio.error(
                "CelebrationSound: Failed to load program \(program): \(error.localizedDescription)"
            )
            return
        }

        audioEngine.ensureRunning()

        for note in notes {
            let startTimer = Timer.scheduledTimer(
                withTimeInterval: note.delay,
                repeats: false
            ) { [weak self] _ in
                self?.sampler.startNote(note.midi, withVelocity: note.velocity, onChannel: 0)
            }
            noteTimers.append(startTimer)

            let stopTimer = Timer.scheduledTimer(
                withTimeInterval: note.delay + noteDuration,
                repeats: false
            ) { [weak self] _ in
                self?.sampler.stopNote(note.midi, onChannel: 0)
            }
            noteTimers.append(stopTimer)
        }
    }

    func attachIfNeeded() {
        guard !isAttached else { return }
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        isAttached = true
    }

    func detach() {
        guard isAttached else { return }
        audioEngine.detach(sampler)
        isAttached = false
    }
}
