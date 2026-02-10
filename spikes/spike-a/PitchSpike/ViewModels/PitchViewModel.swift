import SwiftUI

/// Input mode: real microphone or simulated tone.
enum InputMode: String, CaseIterable {
    case microphone = "Mic"
    case simulator = "Test Tone"
}

/// Bridges audio engine pitch detection to SwiftUI views.
@Observable
final class PitchViewModel {
    // MARK: - Published State

    var frequency: Float = 0
    var noteName: String = "--"
    var confidence: Float = 0
    var centsDeviation: Float = 0
    var isRunning = false
    var errorMessage: String?
    var inputMode: InputMode = .defaultMode

    var latencyMin: Double = 0
    var latencyMax: Double = 0
    var latencyAvg: Double = 0
    var latencyP95: Double = 0
    var sampleCount: Int = 0

    /// Test tone frequency (adjustable via slider).
    var testToneHz: Float = 440.0

    var pitchHistory: [PitchPoint] = []
    let graphTimeWindow: TimeInterval = 20

    // MARK: - Private

    private let latencyTracker = LatencyTracker()
    private var _audioManager: AudioEngineManager?
    private var _toneGenerator: ToneGenerator?
    private var statsTimer: Timer?
    private var startTime: TimeInterval = 0

    private var audioManager: AudioEngineManager {
        if let existing = _audioManager { return existing }
        let manager = AudioEngineManager(
            latencyTracker: latencyTracker
        )
        _audioManager = manager
        return manager
    }

    private var toneGenerator: ToneGenerator {
        if let existing = _toneGenerator { return existing }
        let gen = ToneGenerator(latencyTracker: latencyTracker)
        _toneGenerator = gen
        return gen
    }

    // MARK: - Actions

    func toggleDetection() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    func start() {
        errorMessage = nil
        startTime = CFAbsoluteTimeGetCurrent()

        switch inputMode {
        case .microphone:
            startMicrophone()
        case .simulator:
            startToneGenerator()
        }
    }

    func stop() {
        audioManager.stop()
        toneGenerator.stop()
        isRunning = false
        stopStatsTimer()
        resetDisplay()
    }

    func updateTestTone() {
        toneGenerator.setFrequency(testToneHz)
    }
}

// MARK: - Start Helpers

private extension PitchViewModel {
    func startMicrophone() {
        do {
            audioManager.onPitchDetected = { [weak self] result in
                self?.handlePitch(result)
            }
            try audioManager.start()
            isRunning = true
            startStatsTimer()
        } catch {
            errorMessage = "Mic failed: \(error.localizedDescription). Try Test Tone mode."
            inputMode = .simulator
            startToneGenerator()
        }
    }

    func startToneGenerator() {
        toneGenerator.frequency = testToneHz
        toneGenerator.onPitchDetected = { [weak self] result in
            self?.handlePitch(result)
        }
        toneGenerator.start()
        isRunning = true
        startStatsTimer()
    }
}

// MARK: - Private Helpers

private extension PitchViewModel {
    func handlePitch(_ result: PitchResult) {
        frequency = result.frequency
        noteName = result.noteName
        confidence = result.confidence
        centsDeviation = result.centsDeviation

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let point = PitchPoint(
            time: elapsed,
            frequency: result.frequency,
            confidence: result.confidence
        )
        pitchHistory.append(point)

        let cutoff = elapsed - graphTimeWindow - 5
        if let first = pitchHistory.first, first.time < cutoff {
            pitchHistory.removeAll { $0.time < cutoff }
        }
    }

    func resetDisplay() {
        frequency = 0
        noteName = "--"
        confidence = 0
        centsDeviation = 0
        pitchHistory = []
    }

    func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.updateStats()
        }
    }

    func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    func updateStats() {
        let stats = latencyTracker.stats
        latencyMin = stats.min
        latencyMax = stats.max
        latencyAvg = stats.avg
        latencyP95 = stats.p95
        sampleCount = stats.count
    }
}

// MARK: - Default Mode

private extension InputMode {
    static var defaultMode: InputMode {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        return .microphone
        #endif
    }
}
