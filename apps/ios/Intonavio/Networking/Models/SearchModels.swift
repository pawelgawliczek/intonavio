import Foundation

struct YouTubeSearchResult: Codable, Sendable, Identifiable {
    let videoId: String
    let title: String
    let artist: String
    let duration: Int
    let thumbnailUrl: String
    let url: String
    let hasLyrics: Bool

    var id: String { videoId }

    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
