import Foundation
import AVFoundation

/// Phase D — playback scrub and draw-passage tool. Extensions on the editor
/// view model, split out of `ReferenceEditorViewModel.swift` for the 300-line
/// file-size cap.
@MainActor
extension ReferenceEditorViewModel {

    // MARK: - Playback

    func setupAudioPlayer() {
        let dir = StemDownloader.directory(songId: songId, variantId: baseVariantId)
        let candidates = ["full.mp3", "vocals.mp3", "instrumental.mp3"]
        for name in candidates {
            let url = dir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                AppLogger.pitch.info("Editor playback using \(name)")
                return
            } catch {
                AppLogger.pitch.error(
                    "Editor AVAudioPlayer init failed: \(error.localizedDescription)"
                )
            }
        }
        AppLogger.pitch.info("Editor: no cached stem for playback")
    }

    func togglePlay() {
        guard let player = audioPlayer else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            pollTask?.cancel()
            pollTask = nil
        } else {
            player.play()
            isPlaying = true
            startPolling()
        }
    }

    func seek(to time: Double) {
        let clamped = max(0, min(time, songDuration))
        playbackTime = clamped
        audioPlayer?.currentTime = clamped
    }

    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        pollTask?.cancel()
        pollTask = nil
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000) // ~30 Hz
                guard let self else { return }
                await MainActor.run {
                    guard let player = self.audioPlayer else { return }
                    self.playbackTime = player.currentTime
                    if !player.isPlaying {
                        self.isPlaying = false
                        self.pollTask?.cancel()
                        self.pollTask = nil
                    }
                }
            }
        }
    }

    // MARK: - Stroke commit

    func commitStroke() {
        guard liveStroke.count >= 2 else { liveStroke.removeAll(); return }
        let sorted = liveStroke.sorted { $0.time < $1.time }
        let startT = sorted.first!.time
        let endT = sorted.last!.time
        guard endT > startT else { liveStroke.removeAll(); return }
        let frames = Self.resampleStroke(
            sorted, hop: hopDuration, smooth: smoothStroke, snap: snapToSemitone
        )
        guard !frames.isEmpty else { liveStroke.removeAll(); return }
        let op = PitchEditOp.addPassage(
            id: UUID(),
            range: TimeRange(start: startT, end: endT),
            frames: frames,
            mode: drawMode
        )
        addOperation(op)
        liveStroke.removeAll()
    }

    static func resampleStroke(
        _ stroke: [(time: Double, midi: Double)],
        hop: Double,
        smooth: Bool,
        snap: Bool
    ) -> [ReferencePitchFrame] {
        guard hop > 0, let first = stroke.first, let last = stroke.last else { return [] }
        let startIdx = Int((first.time / hop).rounded(.up))
        let endIdx = Int((last.time / hop).rounded(.down))
        guard endIdx >= startIdx else { return [] }
        var midis: [Double] = []
        var times: [Double] = []
        var j = 0
        for i in startIdx...endIdx {
            let t = Double(i) * hop
            while j + 1 < stroke.count - 1 && stroke[j + 1].time < t { j += 1 }
            let a = stroke[min(j, stroke.count - 1)]
            let b = stroke[min(j + 1, stroke.count - 1)]
            let span = b.time - a.time
            let frac = span > 0 ? (t - a.time) / span : 0
            let midi = a.midi + (b.midi - a.midi) * max(0, min(1, frac))
            midis.append(midi)
            times.append(t)
        }
        if smooth, midis.count >= 3 {
            var out = midis
            for i in 1..<(midis.count - 1) {
                out[i] = (midis[i - 1] + midis[i] + midis[i + 1]) / 3.0
            }
            midis = out
        }
        if snap { midis = midis.map { $0.rounded() } }
        return zip(times, midis).map { t, m in
            let hz = 440.0 * pow(2.0, (m - 69.0) / 12.0)
            return ReferencePitchFrame(
                time: t, frequency: hz, isVoiced: true, midiNote: m, rms: 0.1
            )
        }
    }
}
