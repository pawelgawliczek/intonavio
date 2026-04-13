import AVFoundation
import Foundation

/// Sing-loop phases for the editor's looping record tool.
enum SingLoopPhase: Equatable {
    case idle
    case countdown(Int)
    case recording
    case reviewing
}

/// Sing-to-record tool for the reference editor. Loops the vocal stem over
/// the selected range while capturing the user's voice via PitchDetector.
/// The user keeps looping until they confirm or cancel.
@MainActor
extension ReferenceEditorViewModel {

    // MARK: - Sing Loop Lifecycle

    func startSingLoop() {
        guard let range = currentRange else { return }
        stopPlayback()
        singLoopPhase = .idle
        singLoopFrames = nil
        singLoopCount = 0
        singLoopRange = range
        beginNextPass()
    }

    func confirmSingLoop() {
        guard let frames = singLoopFrames,
              let range = singLoopRange,
              !frames.isEmpty else {
            cancelSingLoop()
            return
        }
        let op = PitchEditOp.addPassage(
            id: UUID(),
            range: range,
            frames: frames,
            mode: drawMode
        )
        addOperation(op)
        cleanupSingLoop()
    }

    func cancelSingLoop() {
        cleanupSingLoop()
    }

    func retakeSingLoop() {
        singLoopFrames = nil
        beginNextPass()
    }

    // MARK: - Internal Loop Flow

    private func beginNextPass() {
        guard let range = singLoopRange else { return }
        singLoopPhase = .countdown(3)
        Task { [weak self] in
            await self?.runCountdownThenRecord(range: range)
        }
    }

    private func runCountdownThenRecord(range: TimeRange) async {
        for i in stride(from: 3, through: 1, by: -1) {
            singLoopPhase = .countdown(i)
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard isSingLooping else { return }
        }
        singLoopPhase = .recording
        recordingProgress = 0
        await capturePass(range: range)
    }

    private func capturePass(range: TimeRange) async {
        let captureEngine = AudioEngine()
        let detector = PitchDetector(engine: captureEngine)

        var captured: [(time: Double, hz: Float, midi: Int)] = []
        let duration = range.end - range.start

        detector.onPitchDetected = { result in
            captured.append((
                time: result.timestamp,
                hz: result.frequency,
                midi: result.midiNote
            ))
        }

        do {
            try detector.start()
        } catch {
            AppLogger.pitch.error(
                "Sing loop: failed to start detector: \(error.localizedDescription)"
            )
            cleanupSingLoop()
            return
        }

        // Start stem playback from range start
        seek(to: range.start)
        audioPlayer?.play()

        let startWall = CFAbsoluteTimeGetCurrent()
        let pollInterval: UInt64 = 50_000_000

        while isSingLooping {
            try? await Task.sleep(nanoseconds: pollInterval)
            let elapsed = CFAbsoluteTimeGetCurrent() - startWall
            recordingProgress = min(elapsed / duration, 1.0)
            if elapsed >= duration { break }
        }

        detector.stop()
        captureEngine.shutdown()
        audioPlayer?.pause()

        guard isSingLooping else { return }

        // Remap wall-clock timestamps to song time
        let remapped = captured.map { entry in
            let elapsed = entry.time - startWall
            return (time: range.start + elapsed, hz: entry.hz, midi: entry.midi)
        }

        let frames = buildFramesFromCapture(remapped, range: range)
        singLoopCount += 1

        if frames.isEmpty {
            // Nothing captured — auto-retry
            beginNextPass()
            return
        }

        singLoopFrames = frames
        singLoopPhase = .reviewing
        recordingProgress = 0
    }

    // MARK: - Helpers

    var isSingLooping: Bool {
        singLoopPhase != .idle
    }

    private func cleanupSingLoop() {
        audioPlayer?.pause()
        singLoopPhase = .idle
        singLoopFrames = nil
        singLoopRange = nil
        singLoopCount = 0
        recordingProgress = 0
    }

    func buildFramesFromCapture(
        _ captured: [(time: Double, hz: Float, midi: Int)],
        range: TimeRange
    ) -> [ReferencePitchFrame] {
        guard !captured.isEmpty else { return [] }

        let startIdx = Int((range.start / hopDuration).rounded(.up))
        let endIdx = Int((range.end / hopDuration).rounded(.down))
        guard endIdx >= startIdx else { return [] }

        let sorted = captured.sorted { $0.time < $1.time }
        var frames: [ReferencePitchFrame] = []
        var captureIdx = 0

        for i in startIdx...endIdx {
            let t = Double(i) * hopDuration
            let bucketStart = t - hopDuration / 2
            let bucketEnd = t + hopDuration / 2

            while captureIdx < sorted.count, sorted[captureIdx].time < bucketStart {
                captureIdx += 1
            }

            var bucketHz: [Float] = []
            var j = captureIdx
            while j < sorted.count, sorted[j].time < bucketEnd {
                bucketHz.append(sorted[j].hz)
                j += 1
            }

            if bucketHz.isEmpty {
                frames.append(ReferencePitchFrame(
                    time: t, frequency: nil, isVoiced: false, midiNote: nil, rms: nil
                ))
            } else {
                let avgHz = Double(bucketHz.reduce(0, +)) / Double(bucketHz.count)
                let midi = 69.0 + 12.0 * log2(avgHz / 440.0)
                frames.append(ReferencePitchFrame(
                    time: t, frequency: avgHz, isVoiced: true, midiNote: midi, rms: 0.1
                ))
            }
        }
        return frames
    }
}
