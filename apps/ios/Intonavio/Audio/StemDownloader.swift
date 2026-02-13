import Foundation

/// Downloads stem audio files from presigned URLs to local cache.
final class StemDownloader {
    private let apiClient: any APIClientProtocol
    private let session: URLSession
    private let cacheDir: URL

    init(
        apiClient: any APIClientProtocol = APIClient(),
        session: URLSession = .shared
    ) {
        self.apiClient = apiClient
        self.session = session

        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        self.cacheDir = caches.appendingPathComponent("stems")
    }

    /// Returns local file URL for a downloaded stem. Downloads if not cached.
    func localURL(
        songId: String,
        stemId: String,
        stemType: StemType
    ) async throws -> URL {
        let dir = cacheDir.appendingPathComponent(songId)
        let fileName = "\(stemType.rawValue.lowercased()).mp3"
        let localFile = dir.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: localFile.path) {
            AppLogger.audio.debug("Stem cached: \(fileName)")
            return localFile
        }

        let presigned = try await apiClient.stemDownloadURL(
            songId: songId,
            stemId: stemId
        )

        guard let downloadURL = URL(string: presigned.url) else {
            throw NetworkError.invalidURL
        }

        let (data, _) = try await session.data(from: downloadURL)

        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        try data.write(to: localFile)

        AppLogger.audio.info("Downloaded stem \(fileName) (\(data.count) bytes)")
        return localFile
    }

    /// Remove cached stems for a song.
    func clearCache(songId: String) {
        let dir = cacheDir.appendingPathComponent(songId)
        try? FileManager.default.removeItem(at: dir)
    }
}
