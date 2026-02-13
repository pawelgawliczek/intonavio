import Foundation

/// Mock API client for SwiftUI previews and unit tests.
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    // Configurable delays and errors for testing
    var shouldFail = false
    var delay: UInt64 = 0

    private func maybeThrow() throws {
        if shouldFail {
            throw APIError(
                statusCode: 500,
                error: "Internal Server Error",
                message: "Mock failure",
                traceId: "trc_mock"
            )
        }
    }
}

// MARK: - Auth

extension MockAPIClient {
    func appleSignIn(_ request: AppleSignInRequest) async throws -> AuthResponse {
        try maybeThrow()
        return Fixtures.authResponse
    }

    func register(_ request: RegisterRequest) async throws -> AuthResponse {
        try maybeThrow()
        return Fixtures.authResponse
    }

    func login(_ request: LoginRequest) async throws -> AuthResponse {
        try maybeThrow()
        return Fixtures.authResponse
    }

    func refreshToken(_ request: RefreshRequest) async throws -> AuthResponse {
        try maybeThrow()
        return Fixtures.authResponse
    }

    func deleteAccount() async throws {
        try maybeThrow()
    }
}

// MARK: - Songs

extension MockAPIClient {
    func createSong(_ request: CreateSongRequest) async throws -> SongResponse {
        try maybeThrow()
        return Fixtures.queuedSong
    }

    func getSong(id: String) async throws -> SongResponse {
        try maybeThrow()
        return Fixtures.readySong
    }

    func listSongs(page: Int, limit: Int) async throws -> PaginatedResponse<SongResponse> {
        try maybeThrow()
        return PaginatedResponse(
            data: Fixtures.songs,
            meta: PaginationMeta(page: 1, limit: 20, total: 2, totalPages: 1)
        )
    }

    func deleteSong(id: String) async throws {
        try maybeThrow()
    }
}

// MARK: - Stems

extension MockAPIClient {
    func listStems(songId: String) async throws -> [StemResponse] {
        try maybeThrow()
        return Fixtures.stems
    }

    func stemDownloadURL(songId: String, stemId: String) async throws -> PresignedURLResponse {
        try maybeThrow()
        return PresignedURLResponse(url: "https://example.com/stem.mp3", expiresIn: 900)
    }

    func pitchDownloadURL(songId: String) async throws -> PresignedURLResponse {
        try maybeThrow()
        return PresignedURLResponse(url: "https://example.com/pitch.json", expiresIn: 900)
    }
}

// MARK: - Sessions

extension MockAPIClient {
    func createSession(_ request: CreateSessionRequest) async throws -> SessionResponse {
        try maybeThrow()
        return Fixtures.session
    }

    func listSessions(page: Int, limit: Int) async throws -> PaginatedResponse<SessionResponse> {
        try maybeThrow()
        return PaginatedResponse(
            data: Fixtures.sessions,
            meta: PaginationMeta(page: 1, limit: 20, total: 1, totalPages: 1)
        )
    }

    func getSession(id: String) async throws -> SessionDetailResponse {
        try maybeThrow()
        return Fixtures.sessionDetail
    }
}

// MARK: - Fixtures

enum Fixtures {
    static let authResponse = AuthResponse(
        accessToken: "mock_access_token",
        refreshToken: "mock_refresh_token",
        user: AuthUser(id: "user1", email: "test@example.com", displayName: "Test User")
    )

    static let stems: [StemResponse] = [
        StemResponse(id: "stem1", type: .vocals, storageKey: "stems/song1/vocals.mp3", format: "mp3"),
        StemResponse(id: "stem2", type: .drums, storageKey: "stems/song1/drums.mp3", format: "mp3"),
        StemResponse(id: "stem3", type: .bass, storageKey: "stems/song1/bass.mp3", format: "mp3"),
        StemResponse(id: "stem4", type: .other, storageKey: "stems/song1/other.mp3", format: "mp3")
    ]

    static let readySong = SongResponse(
        id: "song1",
        videoId: "dQw4w9WgXcQ",
        title: "Rick Astley - Never Gonna Give You Up",
        artist: "Rick Astley",
        thumbnailUrl: "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
        duration: 213,
        status: .ready,
        stems: stems,
        pitchData: PitchDataResponse(id: "pitch1", storageKey: "pitch/song1/reference.json"),
        createdAt: "2025-06-01T12:00:00Z"
    )

    static let queuedSong = SongResponse(
        id: "song2",
        videoId: "uBJdwRPO1QE",
        title: "Processing Song",
        artist: nil,
        thumbnailUrl: "https://img.youtube.com/vi/uBJdwRPO1QE/maxresdefault.jpg",
        duration: 0,
        status: .queued,
        stems: [],
        pitchData: nil,
        createdAt: "2025-06-01T13:00:00Z"
    )

    static let songs = [readySong, queuedSong]

    static let session = SessionResponse(
        id: "sess1",
        songId: "song1",
        duration: 45,
        loopStart: 30.5,
        loopEnd: 55.2,
        speed: 0.75,
        overallScore: 72.5,
        createdAt: "2025-06-01T12:30:00Z"
    )

    static let sessions = [session]

    static let sessionDetail = SessionDetailResponse(
        id: "sess1",
        songId: "song1",
        duration: 45,
        loopStart: 30.5,
        loopEnd: 55.2,
        speed: 0.75,
        overallScore: 72.5,
        pitchLog: [
            PitchLogEntry(time: 30.5, detectedHz: 440.0, referenceHz: 440.0, cents: 0),
            PitchLogEntry(time: 30.55, detectedHz: 442.1, referenceHz: 440.0, cents: 8.3)
        ],
        createdAt: "2025-06-01T12:30:00Z"
    )
}
