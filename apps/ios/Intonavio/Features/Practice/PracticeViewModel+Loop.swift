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
              let a = markerA,
              let b = markerB else {
            return
        }

        if currentTime >= b - 0.05 {
            captureLoopScore()

            controller.seek(to: a)
            if isInStemMode {
                stemPlayer.seek(to: a)
            }
            loopCount += 1
        }
    }

    private func captureLoopScore() {
        guard let engine = scoringEngine else { return }
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
