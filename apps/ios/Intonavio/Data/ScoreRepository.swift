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
    func saveScore(songId: String, phraseIndex: Int?, score: Double) -> Bool {
        let currentBest = fetchBestScore(songId: songId, phraseIndex: phraseIndex)
        let isNewBest = score > currentBest

        let record = ScoreRecord(songId: songId, phraseIndex: phraseIndex, score: score)
        modelContext.insert(record)
        try? modelContext.save()

        return isNewBest
    }

    /// Fetch personal best for song or phrase. Returns 0 if no history.
    func fetchBestScore(songId: String, phraseIndex: Int?) -> Double {
        var descriptor = FetchDescriptor<ScoreRecord>(
            sortBy: [SortDescriptor(\.score, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.predicate = scorePredicate(songId: songId, phraseIndex: phraseIndex)

        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.first?.score ?? 0
    }

    /// Fetch score history, newest first.
    func fetchHistory(songId: String, phraseIndex: Int?, limit: Int = 50) -> [ScoreRecord] {
        var descriptor = FetchDescriptor<ScoreRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.predicate = scorePredicate(songId: songId, phraseIndex: phraseIndex)

        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Private

private extension ScoreRepository {
    func scorePredicate(songId: String, phraseIndex: Int?) -> Predicate<ScoreRecord> {
        if let phraseIndex {
            return #Predicate<ScoreRecord> {
                $0.songId == songId && $0.phraseIndex == phraseIndex
            }
        }
        return #Predicate<ScoreRecord> {
            $0.songId == songId && $0.phraseIndex == nil
        }
    }
}
