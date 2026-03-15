import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var name: String
    var duration: TimeInterval
    var audioFileName: String
    var pitchFrames: Data
    var detectedNotes: Data
    var createdAt: Date
    var noteCount: Int
    var lowestMidi: Int
    var highestMidi: Int

    init(
        name: String,
        duration: TimeInterval,
        audioFileName: String,
        pitchFrames: Data,
        detectedNotes: Data,
        noteCount: Int,
        lowestMidi: Int,
        highestMidi: Int
    ) {
        self.id = UUID()
        self.name = name
        self.duration = duration
        self.audioFileName = audioFileName
        self.pitchFrames = pitchFrames
        self.detectedNotes = detectedNotes
        self.createdAt = .now
        self.noteCount = noteCount
        self.lowestMidi = lowestMidi
        self.highestMidi = highestMidi
    }
}

/// A discrete pitched note detected from offline analysis.
struct DetectedNote: Codable, Sendable {
    let midi: Int
    let name: String
    let startTime: TimeInterval
    let duration: TimeInterval
    let averageHz: Double
    let confidence: Double
}
