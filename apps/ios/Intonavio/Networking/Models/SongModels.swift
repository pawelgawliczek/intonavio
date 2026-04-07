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

enum StemSource: String, Codable, Sendable, CaseIterable {
    case studio = "STUDIO"
    case draft = "DRAFT"

    var displayName: String {
        switch self {
        case .studio: return "Studio"
        case .draft: return "Draft"
        }
    }

    var shortDescription: String {
        switch self {
        case .studio: return "Premium quality, uses your credits"
        case .draft: return "Free, in-house separation"
        }
    }
}

enum VariantStatus: String, Codable, Sendable {
    case queued = "QUEUED"
    case splitting = "SPLITTING"
    case analyzing = "ANALYZING"
    case ready = "READY"
    case failed = "FAILED"

    var isProcessing: Bool {
        switch self {
        case .queued, .splitting, .analyzing: return true
        case .ready, .failed: return false
        }
    }
}

// MARK: - Request DTOs

struct CreateSongRequest: Codable, Sendable {
    let youtubeUrl: String
    let source: StemSource

    init(youtubeUrl: String, source: StemSource = .studio) {
        self.youtubeUrl = youtubeUrl
        self.source = source
    }
}

struct CreateVariantRequest: Codable, Sendable {
    let source: StemSource
}

struct SetActiveVariantRequest: Codable, Sendable {
    let variantId: String
}

// MARK: - Response DTOs

struct SongVariant: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let source: StemSource
    let status: VariantStatus
    let stemsPrefix: String
    let pitchKey: String?
    let frameCount: Int?
    let hopDuration: Double?
    let errorMessage: String?
    let createdAt: String
}

struct SongResponse: Codable, Sendable, Identifiable {
    let id: String
    let videoId: String
    let title: String
    let artist: String?
    let thumbnailUrl: String
    let duration: Int
    let status: SongStatus
    let hasLyrics: Bool?
    let stems: [StemResponse]
    let pitchData: PitchDataResponse?
    let activeVariantId: String?
    let variants: [SongVariant]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, videoId, title, artist, thumbnailUrl, duration, status
        case hasLyrics, stems, pitchData, activeVariantId, variants, createdAt
    }

    init(
        id: String,
        videoId: String,
        title: String,
        artist: String?,
        thumbnailUrl: String,
        duration: Int,
        status: SongStatus,
        hasLyrics: Bool?,
        stems: [StemResponse],
        pitchData: PitchDataResponse?,
        activeVariantId: String? = nil,
        variants: [SongVariant] = [],
        createdAt: String
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.status = status
        self.hasLyrics = hasLyrics
        self.stems = stems
        self.pitchData = pitchData
        self.activeVariantId = activeVariantId
        self.variants = variants
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        videoId = try c.decode(String.self, forKey: .videoId)
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist)
        thumbnailUrl = try c.decode(String.self, forKey: .thumbnailUrl)
        duration = try c.decode(Int.self, forKey: .duration)
        status = try c.decode(SongStatus.self, forKey: .status)
        hasLyrics = try c.decodeIfPresent(Bool.self, forKey: .hasLyrics)
        stems = try c.decodeIfPresent([StemResponse].self, forKey: .stems) ?? []
        pitchData = try c.decodeIfPresent(PitchDataResponse.self, forKey: .pitchData)
        activeVariantId = try c.decodeIfPresent(String.self, forKey: .activeVariantId)
        variants = try c.decodeIfPresent([SongVariant].self, forKey: .variants) ?? []
        createdAt = try c.decode(String.self, forKey: .createdAt)
    }
}

extension SongResponse {
    /// The currently active variant, if variants are populated.
    var activeVariant: SongVariant? {
        guard let activeVariantId else { return variants.first }
        return variants.first { $0.id == activeVariantId } ?? variants.first
    }

    /// Stable cache key for the active variant (falls back to song id).
    var activeCacheKey: String {
        activeVariant?.id ?? id
    }
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
