import Foundation

/// Synchronizes stem audio playback to YouTube video time.
/// YouTube is the master clock — stems follow.
/// Polls YouTube time every 2s and corrects stems if drift exceeds threshold.
final class VideoAudioSync {
    private let controller: YouTubePlayerController
    private let stemPlayer: StemPlayer
    private let driftThreshold: Double
    private var syncTask: Task<Void, Never>?

    var isActive = false

    init(
        controller: YouTubePlayerController,
        stemPlayer: StemPlayer,
        driftThreshold: Double = 0.15
    ) {
        self.controller = controller
        self.stemPlayer = stemPlayer
        self.driftThreshold = driftThreshold
    }

    deinit {
        stop()
    }

    func start() {
        guard !isActive else { return }
        isActive = true

        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, let self else { break }

                await MainActor.run {
                    self.checkDrift()
                }
            }
        }

        AppLogger.sync.info("Video-audio sync started")
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        syncTask?.cancel()
        syncTask = nil
        AppLogger.sync.info("Video-audio sync stopped")
    }

    func correctNow(toTime: Double) {
        stemPlayer.seek(to: toTime)
    }
}

// MARK: - Drift Detection

private extension VideoAudioSync {
    func checkDrift() {
        controller.getCurrentTime { [weak self] ytTime in
            guard let self, self.isActive else { return }

            guard let rawStemTime = self.stemPlayer.currentTime(for: .full)
                    ?? self.stemPlayer.currentTime(for: .vocals)
                    ?? self.stemPlayer.currentTime(for: .other) else {
                return
            }

            // Subtract TimePitch processing latency — the stem's reported
            // time is ahead of actual audio output by this amount.
            let stemTime = rawStemTime - self.stemPlayer.processingLatency
            let drift = ytTime - stemTime

            #if DEBUG
            DriftLogger.shared.log(
                ytTime: ytTime,
                stemTime: stemTime,
                drift: abs(drift)
            )
            #endif

            if abs(drift) > self.driftThreshold {
                AppLogger.sync.debug(
                    "Drift correction: \(String(format: "%.0fms", abs(drift) * 1000))"
                )
                self.stemPlayer.seek(to: ytTime)
            }
        }
    }
}
