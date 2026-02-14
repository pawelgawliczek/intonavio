import Foundation

// MARK: - Enums

enum SongStatus: String, Codable, Sendable {
    case queued = "QUEUED"
    case downloading = "DOWNLOADING"
    case splitting = "SPLITTING"
    case analyzing = "ANALYZING"
    case ready = "READY"
    case failed = "FAILED"

    var isProcessing: Bool {
        switch self {
        case .queued, .downloading, .splitting, .analyzing: return true
        case .ready, .failed: return false
        }
    }
}

enum StemType: String, Codable, Sendable {
    case vocals = "VOCALS"
    case instrumental = "INSTRUMENTAL"
    case drums = "DRUMS"
    case bass = "BASS"
    case other = "OTHER"
    case piano = "PIANO"
    case guitar = "GUITAR"
    case full = "FULL"
}

// MARK: - Request DTOs

struct CreateSongRequest: Codable, Sendable {
    let youtubeUrl: String
}

// MARK: - Response DTOs

struct SongResponse: Codable, Sendable, Identifiable {
    let id: String
    let videoId: String
    let title: String
    let artist: String?
    let thumbnailUrl: String
    let duration: Int
    let status: SongStatus
    let stems: [StemResponse]
    let pitchData: PitchDataResponse?
    let createdAt: String
}

struct StemResponse: Codable, Sendable, Identifiable {
    let id: String
    let type: StemType
    let storageKey: String
    let format: String
}

struct PitchDataResponse: Codable, Sendable, Identifiable {
    let id: String
    let storageKey: String
}

struct PresignedURLResponse: Codable, Sendable {
    let url: String
    let expiresIn: Int
}
