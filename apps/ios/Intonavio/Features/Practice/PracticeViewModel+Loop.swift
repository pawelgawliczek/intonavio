import Foundation

// MARK: - Score Change

enum ScoreChange {
    case better(Double)
    case worse(Double)
    case same
}

// MARK: - Loop Logic

extension PracticeViewModel {
    func startLoopCheck() {
        stopLoopCheck()
        loopCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.checkLoopBoundary()
                }
            }
        }
    }

    func stopLoopCheck() {
        loopCheckTask?.cancel()
        loopCheckTask = nil
    }

    func checkLoopBoundary() {
        guard loopState == .looping,
              !isWaitingForLoopSeek,
              let a = markerA,
              let b = markerB else {
            return
        }

        if currentTime >= b - 0.05 {
            captureLoopScore()
            detectedPoints.removeAll()

            // Stop everything for a clean loop transition.
            controller.pause()
            if isInStemMode {
                stemPlayer.stop()
                sync?.stop()
            }

            // Seek YouTube while paused, then restart both in sync.
            controller.seek(to: a)
            isWaitingForLoopSeek = true
            loopCount += 1

            let targetA = a
            Task { @MainActor in
                // Give YouTube time to complete the seek while paused.
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard self.isWaitingForLoopSeek else { return }
                self.isWaitingForLoopSeek = false

                // Start stem and YouTube simultaneously from marker A.
                if self.isInStemMode {
                    self.stemPlayer.play(from: targetA)
                }
                self.controller.play()

                // Delay sync start so the first drift check doesn't fire
                // while both players are still stabilizing.
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard self.loopState == .looping else { return }
                self.sync?.start()
            }
        }
    }

    private func captureLoopScore() {
        guard let engine = scoringEngine else { return }
        engine.finalizeCurrentPhrase()
        let score = engine.overallScore
        let previousScore = lastLoopScore

        loopScores.append(score)
        lastLoopScore = score

        if let previous = previousScore {
            let delta = score - previous
            if abs(delta) < 0.5 {
                loopScoreImprovement = .same
            } else if delta > 0 {
                loopScoreImprovement = .better(delta)
            } else {
                loopScoreImprovement = .worse(abs(delta))
            }
        } else {
            loopScoreImprovement = nil
        }

        isShowingLoopScore = true
        engine.reset()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.isShowingLoopScore = false
        }
    }
}
