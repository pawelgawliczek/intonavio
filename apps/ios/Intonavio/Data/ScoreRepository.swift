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

        do {
            try modelContext.save()
            AppLogger.pitch.info(
                "Score saved: song=\(songId) phrase=\(String(describing: phraseIndex)) score=\(score) difficulty=\(difficulty.rawValue) newBest=\(isNewBest)"
            )
        } catch {
            AppLogger.pitch.error("Score save FAILED: \(error.localizedDescription)")
        }

        // Debug: count total records in store
        let totalCount = (try? modelContext.fetchCount(FetchDescriptor<ScoreRecord>())) ?? -1
        AppLogger.pitch.info("Total ScoreRecords in store: \(totalCount)")

        return isNewBest
    }

    /// Fetch personal best for song or phrase at given difficulty. Returns 0 if no history.
    func fetchBestScore(
        songId: String,
        phraseIndex: Int?,
        difficulty: DifficultyLevel = .current
    ) -> Double {
        let records = fetchRecords(songId: songId, phraseIndex: phraseIndex, difficulty: difficulty)
        let best = records.map(\.score).max() ?? 0
        AppLogger.pitch.debug(
            "fetchBestScore: song=\(songId) phrase=\(String(describing: phraseIndex)) difficulty=\(difficulty.rawValue) found=\(records.count) best=\(best)"
        )
        return best
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

    /// Fetch all score records for a song (all phrases, all difficulties), newest first.
    func fetchAllScores(songId: String, limit: Int = 1000) -> [ScoreRecord] {
        var descriptor = FetchDescriptor<ScoreRecord>()
        descriptor.predicate = #Predicate<ScoreRecord> { $0.songId == songId }
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        descriptor.fetchLimit = limit

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            AppLogger.pitch.error("fetchAllScores FAILED: \(error.localizedDescription)")
            return []
        }
    }

    /// Delete all score records for a song (all phrases, all difficulties).
    func deleteAllScores(songId: String) {
        var descriptor = FetchDescriptor<ScoreRecord>()
        descriptor.predicate = #Predicate<ScoreRecord> { $0.songId == songId }

        guard let records = try? modelContext.fetch(descriptor) else { return }
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
        AppLogger.pitch.info("Deleted \(records.count) score records for song \(songId)")
    }

    /// Delete all score records across all songs.
    func deleteAllScoresGlobally() {
        let descriptor = FetchDescriptor<ScoreRecord>()
        guard let records = try? modelContext.fetch(descriptor) else { return }
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
        AppLogger.pitch.info("Deleted all \(records.count) score records globally")
    }

    /// Debug: total records in the store (no filters).
    func debugTotalCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<ScoreRecord>())) ?? -1
    }
}

// MARK: - Private

private extension ScoreRepository {
    /// Fetch records matching songId and difficulty, then filter by phraseIndex in Swift.
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

        let all: [ScoreRecord]
        do {
            all = try modelContext.fetch(descriptor)
        } catch {
            AppLogger.pitch.error("Score fetch FAILED: \(error.localizedDescription)")
            return []
        }

        let filtered = all.filter { $0.phraseIndex == phraseIndex }
        AppLogger.pitch.debug(
            "fetchRecords: song=\(songId) phrase=\(String(describing: phraseIndex)) difficulty=\(difficultyRaw) predicate=\(all.count) filtered=\(filtered.count)"
        )
        return filtered
    }
}
