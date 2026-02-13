import Foundation

/// Protocol-oriented API client for testability and SwiftUI previews.
protocol APIClientProtocol: Sendable {
    // Auth
    func appleSignIn(_ request: AppleSignInRequest) async throws -> AuthResponse
    func register(_ request: RegisterRequest) async throws -> AuthResponse
    func login(_ request: LoginRequest) async throws -> AuthResponse
    func refreshToken(_ request: RefreshRequest) async throws -> AuthResponse
    func deleteAccount() async throws

    // Songs
    func createSong(_ request: CreateSongRequest) async throws -> SongResponse
    func getSong(id: String) async throws -> SongResponse
    func listSongs(page: Int, limit: Int) async throws -> PaginatedResponse<SongResponse>
    func deleteSong(id: String) async throws

    // Stems
    func listStems(songId: String) async throws -> [StemResponse]
    func stemDownloadURL(songId: String, stemId: String) async throws -> PresignedURLResponse

    // Pitch
    func pitchDownloadURL(songId: String) async throws -> PresignedURLResponse

    // Sessions
    func createSession(_ request: CreateSessionRequest) async throws -> SessionResponse
    func listSessions(page: Int, limit: Int) async throws -> PaginatedResponse<SessionResponse>
    func getSession(id: String) async throws -> SessionDetailResponse
}
