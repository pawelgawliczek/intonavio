import Foundation
import SwiftData

/// Manages local score persistence and personal best tracking.
final class ScoreRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Save score, return true if new personal best.
    @discardableResult
    func saveScore(
        songId: String,
        phraseIndex: Int?,
        score: Double,
        difficulty: DifficultyLevel = .current
    ) -> Bool {
        let currentBest = fetchBestScore(songId: songId, phraseIndex: phraseIndex, difficulty: difficulty)
        let isNewBest = score > currentBest

        let record = ScoreRecord(
            songId: songId,
            phraseIndex: phraseIndex,
            score: score,
            difficulty: difficulty.rawValue
        )
        modelContext.insert(record)
        try? modelContext.save()

        return isNewBest
    }

    /// Fetch personal best for song or phrase at given difficulty. Returns 0 if no history.
    func fetchBestScore(
        songId: String,
        phraseIndex: Int?,
        difficulty: DifficultyLevel = .current
    ) -> Double {
        fetchRecords(songId: songId, phraseIndex: phraseIndex, difficulty: difficulty)
            .map(\.score)
            .max() ?? 0
    }

    /// Fetch score history, newest first, for a specific difficulty.
    func fetchHistory(
        songId: String,
        phraseIndex: Int?,
        difficulty: DifficultyLevel = .current,
        limit: Int = 50
    ) -> [ScoreRecord] {
        let records = fetchRecords(songId: songId, phraseIndex: phraseIndex, difficulty: difficulty)
        let sorted = records.sorted { $0.date > $1.date }
        return Array(sorted.prefix(limit))
    }
}

// MARK: - Private

private extension ScoreRepository {
    /// Fetch records matching songId and difficulty, then filter by phraseIndex in Swift.
    /// Avoids SwiftData #Predicate issues with optional Int? comparisons.
    func fetchRecords(
        songId: String,
        phraseIndex: Int?,
        difficulty: DifficultyLevel
    ) -> [ScoreRecord] {
        let difficultyRaw = difficulty.rawValue
        var descriptor = FetchDescriptor<ScoreRecord>()
        descriptor.predicate = #Predicate<ScoreRecord> {
            $0.songId == songId && $0.difficulty == difficultyRaw
        }

        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.phraseIndex == phraseIndex }
    }
}
