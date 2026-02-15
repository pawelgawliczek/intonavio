import AVFoundation

/// Plays exercise notes as MIDI through an AVAudioUnitSampler loaded
/// with a SoundFont instrument. Mirrors the `MetronomeTick` attach pattern
/// and supports vibrato via MIDI pitch bend.
final class GuideTone {
    private let audioEngine: AudioEngine
    private let sampler = AVAudioUnitSampler()
    private var isAttached = false
    private(set) var isRunning = false

    // Note scheduling state
    private var noteEvents: [NoteEvent] = []
    private var currentNoteIndex = 0
    private var noteTimer: Timer?
    private var vibratoTimer: Timer?
    private var currentNoteStartTime: Date?
    private var currentMidiNote: UInt8?

    // Settings
    private(set) var instrument: GuideToneInstrument

    struct NoteEvent {
        let midiNote: UInt8
        let duration: TimeInterval
        let hasVibrato: Bool
        let isRest: Bool
    }

    init(engine: AudioEngine) {
        self.audioEngine = engine
        let stored = UserDefaults.standard.integer(forKey: "guideToneInstrument")
        self.instrument = GuideToneInstrument(rawValue: stored) ?? .acousticGrandPiano
    }

    // MARK: - Public API

    /// Load a SoundFont instrument into the sampler.
    func loadInstrument(_ newInstrument: GuideToneInstrument) {
        instrument = newInstrument
        attachIfNeeded()
        guard let url = soundFontURL() else {
            AppLogger.audio.error("SoundFont file not found in bundle")
            return
        }
        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: newInstrument.program,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            AppLogger.audio.info("Loaded guide tone instrument: \(newInstrument.label)")
        } catch {
            AppLogger.audio.error(
                "Failed to load instrument: \(error.localizedDescription)"
            )
        }
    }

    /// Convert exercise notes and tempo into timed note events.
    func prepare(notes: [ExerciseNote], tempo: Int) {
        let beatDuration = 60.0 / Double(tempo)
        noteEvents = notes.map { note in
            NoteEvent(
                midiNote: UInt8(clamping: note.midiNote),
                duration: note.durationBeats * beatDuration,
                hasVibrato: note.hasVibrato,
                isRest: note.isRest
            )
        }
        currentNoteIndex = 0
        loadInstrument(instrument)
    }

    /// Begin playing notes sequentially from the first note.
    func start() {
        guard !isRunning, !noteEvents.isEmpty else { return }
        attachIfNeeded()
        audioEngine.ensureRunning()
        isRunning = true
        currentNoteIndex = 0
        playNextNote()
    }

    /// Stop playback, silence current note, invalidate timers.
    func stop() {
        guard isRunning else { return }
        stopCurrentNote()
        noteTimer?.invalidate()
        noteTimer = nil
        isRunning = false
    }

    /// Play a single preview note for the settings instrument picker.
    /// Starts the engine if needed so this works standalone.
    func playPreview(midiNote: UInt8 = 60, duration: TimeInterval = 0.5) {
        attachIfNeeded()
        do {
            try audioEngine.start()
        } catch {
            AppLogger.audio.error(
                "Failed to start engine for preview: \(error.localizedDescription)"
            )
            return
        }
        sampler.startNote(midiNote, withVelocity: 80, onChannel: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.sampler.stopNote(midiNote, onChannel: 0)
        }
    }

    deinit {
        stop()
        detach()
    }
}

// MARK: - Private

private extension GuideTone {
    func attachIfNeeded() {
        guard !isAttached else { return }
        audioEngine.attach(sampler)
        audioEngine.connect(
            sampler,
            to: audioEngine.mainMixerNode,
            format: nil
        )
        isAttached = true
    }

    func detach() {
        guard isAttached else { return }
        audioEngine.detach(sampler)
        isAttached = false
    }

    func soundFontURL() -> URL? {
        Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2")
    }

    func playNextNote() {
        guard isRunning, currentNoteIndex < noteEvents.count else {
            isRunning = false
            return
        }

        let event = noteEvents[currentNoteIndex]
        currentNoteIndex += 1

        if event.isRest {
            scheduleNextAfter(duration: event.duration)
            return
        }

        // Start the note
        currentMidiNote = event.midiNote
        currentNoteStartTime = Date()
        sampler.sendPitchBend(8192, onChannel: 0) // Center pitch bend
        sampler.startNote(event.midiNote, withVelocity: 90, onChannel: 0)

        if event.hasVibrato {
            startVibratoTimer()
        }

        scheduleNextAfter(duration: event.duration)
    }

    func scheduleNextAfter(duration: TimeInterval) {
        noteTimer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            self?.stopCurrentNote()
            self?.playNextNote()
        }
    }

    func stopCurrentNote() {
        vibratoTimer?.invalidate()
        vibratoTimer = nil
        if let midi = currentMidiNote {
            sampler.stopNote(midi, onChannel: 0)
            sampler.sendPitchBend(8192, onChannel: 0) // Reset to center
            currentMidiNote = nil
        }
        currentNoteStartTime = nil
    }

    func startVibratoTimer() {
        vibratoTimer?.invalidate()
        vibratoTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0, // ~60 Hz update rate
            repeats: true
        ) { [weak self] _ in
            self?.updateVibrato()
        }
    }

    /// Modulate pitch bend to produce vibrato matching the reference pitch
    /// generator: +/- 30 cents at 5.5 Hz with a 0.3s ramp-in.
    func updateVibrato() {
        guard let startTime = currentNoteStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let ramp = min(1.0, elapsed / 0.3)
        let modulation = sin(2.0 * .pi * 5.5 * elapsed)
        let centsOffset = 30.0 * modulation * ramp

        // MIDI pitch bend range is 0...16383, center is 8192.
        // Default pitch bend range is +/- 2 semitones (200 cents).
        let bendValue = 8192.0 + (centsOffset / 200.0) * 8192.0
        let clamped = UInt16(clamping: Int(bendValue.rounded()))
        sampler.sendPitchBend(clamped, onChannel: 0)
    }
}
