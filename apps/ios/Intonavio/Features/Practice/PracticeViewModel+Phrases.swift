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

        if isNewBest {
            celebrationSound?.playPhraseBest()
        }

        // Save song score after the last phrase completes
        let isLastPhrase = totalPhrases > 0 && result.phraseIndex == totalPhrases - 1
        if isLastPhrase {
            saveSongScore()
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.isShowingPhraseScore = false
        }
    }

    /// Save song-level score when session ends. Returns true if new best.
    /// Skips saving if the user seeked/looped or already saved this session.
    @discardableResult
    func saveSongScore() -> Bool {
        guard !isSongScoreInvalidated, !isSongScoreSaved else { return false }
        guard let engine = scoringEngine else { return false }

        // Set early to prevent re-entrancy: finalizeCurrentPhrase() fires
        // onPhraseCompleted, which calls handlePhraseCompleted, which calls
        // saveSongScore() again for the last phrase.
        isSongScoreSaved = true
        engine.finalizeCurrentPhrase()

        let score = engine.overallScore
        guard score > 0 else { return false }

        // Capture previous best before saving
        let previousBest = scoreRepository?.fetchBestScore(
            songId: songId, phraseIndex: nil
        ) ?? 0

        let isNewBest = scoreRepository?.saveScore(
            songId: songId,
            phraseIndex: nil,
            score: score
        ) ?? false

        if isNewBest {
            isSongNewBest = true
            songBestScore = score
            celebrationSound?.playSongBest()
        }

        finalizeBestTake(isNewBest: isNewBest)
        buildPerformanceSummary(score: score, isNewBest: isNewBest, previousBest: previousBest)
        showPerformanceSummaryAfterDelay()
        return isNewBest
    }
}

// MARK: - Performance Summary

private extension PracticeViewModel {
    func buildPerformanceSummary(score: Double, isNewBest: Bool, previousBest: Double) {
        guard let repo = scoreRepository, let engine = scoringEngine else { return }

        // Count phrase personal bests from this run
        var phrasePBCount = 0
        var weakestIndex: Int?
        var weakestScore: Double = .infinity

        for (index, result) in engine.phraseScores {
            let prevPhraseBest = repo.fetchBestScore(
                songId: songId, phraseIndex: index
            )
            // The score was already saved, so if this run's score equals the best,
            // it's a PB (this run set it).
            if result.score >= prevPhraseBest, result.score > 0 {
                phrasePBCount += 1
            }
            if result.score < weakestScore {
                weakestScore = result.score
                weakestIndex = index
            }
        }

        // Delta from last attempt (previous song-level score, not best)
        let history = repo.fetchHistory(songId: songId, phraseIndex: nil, limit: 5)
        // history[0] is the score we just saved, history[1] is the previous attempt
        let deltaFromLast: Double? = history.count >= 2
            ? score - history[1].score
            : nil

        // Improving streak: count consecutive improvements from most recent
        let improvingStreak = computeImprovingStreak(history: history)

        performanceSummary = PerformanceSummary(
            score: score,
            isNewBest: isNewBest,
            previousBest: previousBest,
            totalPhrases: totalPhrases,
            phrasePBCount: phrasePBCount,
            deltaFromLastAttempt: deltaFromLast,
            improvingStreak: improvingStreak,
            weakestPhraseIndex: weakestIndex,
            weakestPhraseScore: weakestScore.isFinite ? weakestScore : nil
        )
    }

    func computeImprovingStreak(history: [ScoreRecord]) -> Int {
        guard history.count >= 2 else { return 0 }
        var streak = 0
        for i in 0..<(history.count - 1) {
            if history[i].score > history[i + 1].score {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    func showPerformanceSummaryAfterDelay() {
        // Show summary after the song best toast has time to display
        let delay: UInt64 = isSongNewBest ? 2_500_000_000 : 500_000_000
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            self.isSongNewBest = false
            self.isShowingPerformanceSummary = true
        }
    }
}
