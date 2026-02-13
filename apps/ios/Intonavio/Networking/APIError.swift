import Foundation

/// API error matching the backend's consistent error format.
struct APIError: Error, Codable, Sendable {
    let statusCode: Int
    let error: String
    let message: String
    let traceId: String?
}

extension APIError: LocalizedError {
    var errorDescription: String? { message }
}

/// Networking-level errors distinct from API response errors.
enum NetworkError: Error, LocalizedError {
    case noData
    case decodingFailed(Error)
    case unauthorized
    case invalidURL
    case tokenRefreshFailed

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data received"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .invalidURL:
            return "Invalid URL"
        case .tokenRefreshFailed:
            return "Token refresh failed"
        }
    }
}
