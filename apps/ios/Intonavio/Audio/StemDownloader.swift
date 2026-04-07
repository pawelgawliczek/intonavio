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
    /// Pass `variantId` so two variants of the same song can be cached side by side.
    func localURL(
        songId: String,
        stemId: String,
        stemType: StemType,
        variantId: String? = nil
    ) async throws -> URL {
        let dir = Self.directory(songId: songId, variantId: variantId)
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

    /// Check if all stems for a variant are already cached locally.
    static func isCached(
        songId: String,
        stems: [StemResponse],
        variantId: String? = nil
    ) -> Bool {
        guard !stems.isEmpty else { return false }
        let dir = directory(songId: songId, variantId: variantId)

        return stems.allSatisfy { stem in
            let fileName = "\(stem.type.rawValue.lowercased()).mp3"
            let path = dir.appendingPathComponent(fileName).path
            return FileManager.default.fileExists(atPath: path)
        }
    }

    /// Remove cached stems for every variant of a song.
    func clearCache(songId: String) {
        let dir = cacheDir.appendingPathComponent(songId)
        try? FileManager.default.removeItem(at: dir)
    }

    static func directory(songId: String, variantId: String?) -> URL {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        let songDir = caches
            .appendingPathComponent("stems")
            .appendingPathComponent(songId)
        if let variantId, !variantId.isEmpty {
            return songDir.appendingPathComponent(variantId)
        }
        return songDir
    }
}
