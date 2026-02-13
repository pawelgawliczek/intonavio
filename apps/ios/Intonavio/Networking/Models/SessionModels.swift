import Foundation

// MARK: - Request DTOs

struct CreateSessionRequest: Codable, Sendable {
    let songId: String
    let duration: Int
    let loopStart: Double?
    let loopEnd: Double?
    let speed: Double?
    let overallScore: Double
    let pitchLog: [PitchLogEntry]
}

struct PitchLogEntry: Codable, Sendable {
    let time: Double
    let detectedHz: Double?
    let referenceHz: Double?
    let cents: Double?
}

// MARK: - Response DTOs

struct SessionResponse: Codable, Sendable, Identifiable {
    let id: String
    let songId: String
    let duration: Int
    let loopStart: Double?
    let loopEnd: Double?
    let speed: Double
    let overallScore: Double
    let createdAt: String
}

struct SessionDetailResponse: Codable, Sendable, Identifiable {
    let id: String
    let songId: String
    let duration: Int
    let loopStart: Double?
    let loopEnd: Double?
    let speed: Double
    let overallScore: Double
    let pitchLog: [PitchLogEntry]
    let createdAt: String
}
