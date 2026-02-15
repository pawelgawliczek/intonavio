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
        var descriptor = FetchDescriptor<ScoreRecord>(
            sortBy: [SortDescriptor(\.score, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.predicate = scorePredicate(songId: songId, phraseIndex: phraseIndex, difficulty: difficulty)

        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.first?.score ?? 0
    }

    /// Fetch score history, newest first, for a specific difficulty.
    func fetchHistory(
        songId: String,
        phraseIndex: Int?,
        difficulty: DifficultyLevel = .current,
        limit: Int = 50
    ) -> [ScoreRecord] {
        var descriptor = FetchDescriptor<ScoreRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.predicate = scorePredicate(songId: songId, phraseIndex: phraseIndex, difficulty: difficulty)

        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Private

private extension ScoreRepository {
    func scorePredicate(
        songId: String,
        phraseIndex: Int?,
        difficulty: DifficultyLevel
    ) -> Predicate<ScoreRecord> {
        let difficultyRaw = difficulty.rawValue
        if let phraseIndex {
            return #Predicate<ScoreRecord> {
                $0.songId == songId && $0.phraseIndex == phraseIndex && $0.difficulty == difficultyRaw
            }
        }
        return #Predicate<ScoreRecord> {
            $0.songId == songId && $0.phraseIndex == nil && $0.difficulty == difficultyRaw
        }
    }
}
