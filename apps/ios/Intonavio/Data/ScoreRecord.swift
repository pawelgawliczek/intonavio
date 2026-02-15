import Foundation
import SwiftData

@Model
final class ScoreRecord {
    var songId: String
    var phraseIndex: Int?  // nil = song-level score
    var score: Double
    var date: Date
    var difficulty: Int = 0  // DifficultyLevel raw value (default: beginner)

    init(
        songId: String,
        phraseIndex: Int? = nil,
        score: Double,
        difficulty: Int = DifficultyLevel.current.rawValue,
        date: Date = .now
    ) {
        self.songId = songId
        self.phraseIndex = phraseIndex
        self.score = score
        self.difficulty = difficulty
        self.date = date
    }
}
