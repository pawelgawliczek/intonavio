import Foundation

/// Generic paginated response matching the backend format.
struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: [T]
    let meta: PaginationMeta
}

struct PaginationMeta: Codable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}
