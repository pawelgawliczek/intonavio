import AVFoundation
import Foundation

/// Sing-to-record tool for the reference editor. Records the user's voice
/// via PitchDetector and converts detected pitches into an addPassage operation.
@MainActor
extension ReferenceEditorViewModel {

    // MARK: - Sing Recording

    func startSinging() {
        guard let range = currentRange else { return }

        stopPlayback()
        isRecording = true
        recordingProgress = 0
        recordingCountdown = 3

        Task { [weak self] in
            await self?.runCountdownAndRecord(range: range)
        }
    }

    func cancelSinging() {
        isRecording = false
        recordingCountdown = 0
        recordingProgress = 0
        singCleanup()
    }

    private func runCountdownAndRecord(range: TimeRange) async {
        // 3-2-1 countdown
        for i in stride(from: 3, through: 1, by: -1) {
            recordingCountdown = i
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard isRecording else { return }
        }
        recordingCountdown = 0

        await recordVoice(range: range)
    }

    private func recordVoice(range: TimeRange) async {
        let engine = AudioEngine()
        let detector = PitchDetector(engine: engine)

        var captured: [(time: Double, hz: Float, midi: Int)] = []
        let duration = range.end - range.start
        let startWall = CFAbsoluteTimeGetCurrent()

        detector.onPitchDetected = { result in
            let elapsed = CFAbsoluteTimeGetCurrent() - startWall
            guard elapsed >= 0, elapsed <= duration + 0.1 else { return }
            captured.append((time: range.start + elapsed, hz: result.frequency, midi: result.midiNote))
        }

        do {
            try detector.start()
        } catch {
            AppLogger.pitch.error("Sing tool: failed to start detector: \(error.localizedDescription)")
            isRecording = false
            return
        }

        // Poll progress until duration elapsed
        let pollInterval: UInt64 = 50_000_000 // 50ms
        while isRecording {
            try? await Task.sleep(nanoseconds: pollInterval)
            let elapsed = CFAbsoluteTimeGetCurrent() - startWall
            recordingProgress = min(elapsed / duration, 1.0)
            if elapsed >= duration { break }
        }

        detector.stop()
        engine.shutdown()

        guard isRecording, !captured.isEmpty else {
            isRecording = false
            recordingProgress = 0
            return
        }

        let frames = buildFramesFromCapture(captured, range: range)
        guard !frames.isEmpty else {
            isRecording = false
            recordingProgress = 0
            return
        }

        let op = PitchEditOp.addPassage(
            id: UUID(),
            range: range,
            frames: frames,
            mode: drawMode
        )
        addOperation(op)

        isRecording = false
        recordingProgress = 0
    }

    private func buildFramesFromCapture(
        _ captured: [(time: Double, hz: Float, midi: Int)],
        range: TimeRange
    ) -> [ReferencePitchFrame] {
        guard !captured.isEmpty else { return [] }

        let startIdx = Int((range.start / hopDuration).rounded(.up))
        let endIdx = Int((range.end / hopDuration).rounded(.down))
        guard endIdx >= startIdx else { return [] }

        // Group detections into hop-aligned buckets
        var frames: [ReferencePitchFrame] = []
        var captureIdx = 0
        let sorted = captured.sorted { $0.time < $1.time }

        for i in startIdx...endIdx {
            let t = Double(i) * hopDuration
            let bucketStart = t - hopDuration / 2
            let bucketEnd = t + hopDuration / 2

            // Advance to first detection in this bucket
            while captureIdx < sorted.count, sorted[captureIdx].time < bucketStart {
                captureIdx += 1
            }

            // Collect detections in bucket
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

    private func singCleanup() {
        // No persistent state to clean — AudioEngine is created/destroyed per recording
    }
}
