import Foundation

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
            controller.seek(to: a)
            if isInStemMode {
                stemPlayer.seek(to: a)
            }
            loopCount += 1
        }
    }
}
