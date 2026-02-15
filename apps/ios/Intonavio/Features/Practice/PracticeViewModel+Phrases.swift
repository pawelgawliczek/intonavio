import Foundation

// MARK: - Phrase Scoring

extension PracticeViewModel {
    /// Wire up phrase scoring after configure().
    func setupPhraseScoring() {
        totalPhrases = referenceStore.phraseCount
        songBestScore = scoreRepository?.fetchBestScore(songId: songId, phraseIndex: nil) ?? 0

        scoringEngine?.onPhraseCompleted = { [weak self] result in
            self?.handlePhraseCompleted(result)
        }
    }

    /// Called when a phrase finishes scoring.
    func handlePhraseCompleted(_ result: PhraseScoreResult) {
        currentPhraseScore = result.score
        currentPhraseIndex = result.phraseIndex

        let isNewBest = scoreRepository?.saveScore(
            songId: songId,
            phraseIndex: result.phraseIndex,
            score: result.score
        ) ?? false

        isPhraseNewBest = isNewBest
        isShowingPhraseScore = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.isShowingPhraseScore = false
        }
    }

    /// Save song-level score when session ends. Returns true if new best.
    @discardableResult
    func saveSongScore() -> Bool {
        guard let engine = scoringEngine else { return false }
        engine.finalizeCurrentPhrase()

        let score = engine.overallScore
        guard score > 0 else { return false }

        let isNewBest = scoreRepository?.saveScore(
            songId: songId,
            phraseIndex: nil,
            score: score
        ) ?? false

        if isNewBest {
            isSongNewBest = true
            songBestScore = score
        }

        return isNewBest
    }
}
