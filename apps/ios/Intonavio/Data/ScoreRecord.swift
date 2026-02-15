import Foundation
import SwiftData

@Model
final class ScoreRecord {
    var songId: String
    var phraseIndex: Int?  // nil = song-level score
    var score: Double
    var date: Date

    init(songId: String, phraseIndex: Int? = nil, score: Double, date: Date = .now) {
        self.songId = songId
        self.phraseIndex = phraseIndex
        self.score = score
        self.date = date
    }
}
