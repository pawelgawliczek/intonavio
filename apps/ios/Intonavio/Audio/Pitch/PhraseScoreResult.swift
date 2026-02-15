import Foundation

/// Score result for a single completed phrase.
struct PhraseScoreResult: Sendable {
    let phraseIndex: Int
    let score: Double       // 0-100
    let startTime: Double
    let endTime: Double
}
