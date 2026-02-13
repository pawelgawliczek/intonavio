import Foundation

// MARK: - Request DTOs

struct AppleSignInRequest: Codable, Sendable {
    let identityToken: String
    let authorizationCode: String
    let fullName: String?
}

struct RegisterRequest: Codable, Sendable {
    let email: String
    let password: String
    let displayName: String
}

struct LoginRequest: Codable, Sendable {
    let email: String
    let password: String
}

struct RefreshRequest: Codable, Sendable {
    let refreshToken: String
}

// MARK: - Response DTOs

struct AuthResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}

struct AuthUser: Codable, Sendable, Identifiable {
    let id: String
    let email: String?
    let displayName: String
}
