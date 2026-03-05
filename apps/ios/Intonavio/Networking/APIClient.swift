import Foundation

/// URLSession-based API client with automatic token refresh on 401.
final class APIClient: APIClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: String
    private let tokenManager: TokenManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var isRefreshing = false

    var onAuthFailure: (@Sendable () -> Void)?

    init(
        session: URLSession = .shared,
        tokenManager: TokenManager = .shared
    ) {
        self.session = session
        self.tokenManager = tokenManager
        self.baseURL = Self.resolveBaseURL()
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    private static func resolveBaseURL() -> String {
        if let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !url.isEmpty, !url.contains("$(") {
            return url
        }
        return "http://localhost:3000/v1"
    }
}

// MARK: - APIClientProtocol

extension APIClient {
    func appleSignIn(_ request: AppleSignInRequest) async throws -> AuthResponse {
        try await execute(.appleSignIn(request))
    }

    func register(_ request: RegisterRequest) async throws -> AuthResponse {
        try await execute(.register(request))
    }

    func login(_ request: LoginRequest) async throws -> AuthResponse {
        try await execute(.login(request))
    }

    func refreshToken(_ request: RefreshRequest) async throws -> AuthResponse {
        try await execute(.refreshToken(request))
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await execute(.deleteAccount)
    }

    func createSong(_ request: CreateSongRequest) async throws -> SongResponse {
        try await execute(.createSong(request))
    }

    func getSong(id: String) async throws -> SongResponse {
        try await execute(.getSong(id: id))
    }

    func listSongs(page: Int, limit: Int) async throws -> PaginatedResponse<SongResponse> {
        try await execute(.listSongs(page: page, limit: limit))
    }

    func deleteSong(id: String) async throws {
        let _: EmptyResponse = try await execute(.deleteSong(id: id))
    }

    func listStems(songId: String) async throws -> [StemResponse] {
        try await execute(.listStems(songId: songId))
    }

    func stemDownloadURL(songId: String, stemId: String) async throws -> PresignedURLResponse {
        try await execute(.stemDownloadURL(songId: songId, stemId: stemId))
    }

    func pitchDownloadURL(songId: String) async throws -> PresignedURLResponse {
        try await execute(.pitchDownloadURL(songId: songId))
    }

    func createSession(_ request: CreateSessionRequest) async throws -> SessionResponse {
        try await execute(.createSession(request))
    }

    func listSessions(page: Int, limit: Int) async throws -> PaginatedResponse<SessionResponse> {
        try await execute(.listSessions(page: page, limit: limit))
    }

    func getSession(id: String) async throws -> SessionDetailResponse {
        try await execute(.getSession(id: id))
    }
}

// MARK: - Request Execution

private extension APIClient {
    func execute<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let request = try buildRequest(for: endpoint)
        logRequest(request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        if httpResponse.statusCode == 401, endpoint.requiresAuth {
            return try await handleUnauthorized(endpoint: endpoint)
        }

        return try handleResponse(data: data, statusCode: httpResponse.statusCode)
    }

    func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth, let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

    func handleResponse<T: Decodable>(data: Data, statusCode: Int) throws -> T {
        if statusCode >= 200, statusCode < 300 {
            if T.self == EmptyResponse.self, data.isEmpty {
                return EmptyResponse() as! T // swiftlint:disable:this force_cast
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed(error)
            }
        }

        if let apiError = try? decoder.decode(APIError.self, from: data) {
            throw apiError
        }

        throw APIError(
            statusCode: statusCode,
            error: "Unknown",
            message: "Request failed with status \(statusCode)",
            traceId: nil
        )
    }

    func handleUnauthorized<T: Decodable>(endpoint: APIEndpoint) async throws -> T {
        guard !isRefreshing else { throw NetworkError.unauthorized }

        guard let refreshTokenValue = tokenManager.refreshToken else {
            onAuthFailure?()
            throw NetworkError.unauthorized
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let refreshResponse: AuthResponse = try await execute(
                .refreshToken(RefreshRequest(refreshToken: refreshTokenValue))
            )
            tokenManager.storeTokens(
                access: refreshResponse.accessToken,
                refresh: refreshResponse.refreshToken
            )
            return try await execute(endpoint)
        } catch {
            tokenManager.clearTokens()
            onAuthFailure?()
            throw NetworkError.tokenRefreshFailed
        }
    }

    func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        AppLogger.network.debug("\(method) \(url)")
        #endif
    }
}

// MARK: - Helpers

private struct EmptyResponse: Decodable {}

/// Type-erased Encodable wrapper for endpoint bodies.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        self._encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
