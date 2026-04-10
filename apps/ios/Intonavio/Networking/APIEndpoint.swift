import Foundation

/// Defines all API endpoints with path, method, and optional body.
enum APIEndpoint {
    // Auth
    case appleSignIn(AppleSignInRequest)
    case register(RegisterRequest)
    case login(LoginRequest)
    case refreshToken(RefreshRequest)
    case deleteAccount

    // Songs
    case searchSongs(query: String, limit: Int)
    case previewSong(youtubeUrl: String)
    case createSong(CreateSongRequest)
    case getSong(id: String)
    case listSongs(page: Int, limit: Int)
    case deleteSong(id: String)

    // Variants
    case createVariant(songId: String, body: CreateVariantRequest)
    case setActiveVariant(songId: String, body: SetActiveVariantRequest)

    // Stems
    case listStems(songId: String)
    case stemDownloadURL(songId: String, stemId: String)

    // Pitch
    case pitchDownloadURL(songId: String, variantId: String?)

    // Sessions
    case createSession(CreateSessionRequest)
    case listSessions(page: Int, limit: Int)
    case getSession(id: String)

    var path: String {
        switch self {
        case .appleSignIn: return "/auth/apple"
        case .register: return "/auth/register"
        case .login: return "/auth/login"
        case .refreshToken: return "/auth/refresh"
        case .deleteAccount: return "/auth/account"
        case .searchSongs: return "/songs/search"
        case .previewSong: return "/songs/preview"
        case .createSong: return "/songs"
        case .getSong(let id): return "/songs/\(id)"
        case .listSongs: return "/songs"
        case .deleteSong(let id): return "/songs/\(id)"
        case .createVariant(let songId, _): return "/songs/\(songId)/variants"
        case .setActiveVariant(let songId, _): return "/songs/\(songId)/active-variant"
        case .listStems(let songId): return "/songs/\(songId)/stems"
        case .stemDownloadURL(let songId, let stemId):
            return "/songs/\(songId)/stems/\(stemId)/url"
        case let .pitchDownloadURL(songId, _):
            return "/songs/\(songId)/pitch/url"
        case .createSession: return "/sessions"
        case .listSessions: return "/sessions"
        case .getSession(let id): return "/sessions/\(id)"
        }
    }

    var method: String {
        switch self {
        case .appleSignIn, .register, .login,
             .refreshToken, .createSong, .createSession, .createVariant:
            return "POST"
        case .setActiveVariant:
            return "PATCH"
        case .deleteAccount, .deleteSong:
            return "DELETE"
        case .getSong, .listSongs, .searchSongs, .previewSong, .listStems,
             .stemDownloadURL, .pitchDownloadURL,
             .listSessions, .getSession:
            return "GET"
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .appleSignIn(let req): return req
        case .register(let req): return req
        case .login(let req): return req
        case .refreshToken(let req): return req
        case .createSong(let req): return req
        case .createSession(let req): return req
        case .createVariant(_, let req): return req
        case .setActiveVariant(_, let req): return req
        default: return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .searchSongs(let query, let limit):
            return [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .previewSong(let youtubeUrl):
            return [
                URLQueryItem(name: "youtubeUrl", value: youtubeUrl)
            ]
        case .listSongs(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .listSessions(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .pitchDownloadURL(_, let variantId):
            guard let variantId else { return nil }
            return [URLQueryItem(name: "variantId", value: variantId)]
        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .appleSignIn, .register, .login, .refreshToken:
            return false
        default:
            return true
        }
    }
}
