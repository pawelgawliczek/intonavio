import Foundation

/// Downloads pitch JSON from R2 via presigned URL and caches locally.
/// Cache location: ~/Library/Caches/pitch/{songId}/reference.json
enum PitchDataDownloader {
    private static let fileManager = FileManager.default

    /// Returns the local URL for cached pitch data. Downloads if not cached.
    static func localURL(
        songId: String,
        apiClient: any APIClientProtocol
    ) async throws -> URL {
        let cached = cacheURL(for: songId)
        if fileManager.fileExists(atPath: cached.path()) {
            AppLogger.pitch.debug("Pitch data cache hit for \(songId)")
            return cached
        }

        let response = try await apiClient.pitchDownloadURL(songId: songId)
        guard let downloadURL = URL(string: response.url) else {
            throw PitchDownloadError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: downloadURL)

        let directory = cached.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: cached)

        AppLogger.pitch.info("Pitch data downloaded for \(songId)")
        return cached
    }

    /// Check if pitch data is already cached for a song.
    static func isCached(songId: String) -> Bool {
        fileManager.fileExists(atPath: cacheURL(for: songId).path())
    }

    /// Remove cached pitch data for a song.
    static func removeCache(songId: String) {
        let url = cacheURL(for: songId).deletingLastPathComponent()
        try? fileManager.removeItem(at: url)
    }

    /// Remove all cached pitch data for every song.
    static func clearAllCache() {
        let caches = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        let pitchDir = caches.appendingPathComponent("pitch", isDirectory: true)
        try? fileManager.removeItem(at: pitchDir)
        AppLogger.pitch.info("All pitch data cache cleared")
    }

    private static func cacheURL(for songId: String) -> URL {
        let caches = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        return caches
            .appendingPathComponent("pitch", isDirectory: true)
            .appendingPathComponent(songId, isDirectory: true)
            .appendingPathComponent("reference.json")
    }
}

enum PitchDownloadError: Error {
    case invalidURL
}
