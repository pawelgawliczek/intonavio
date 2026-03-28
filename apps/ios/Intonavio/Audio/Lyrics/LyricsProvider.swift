import Foundation

/// Fetches, caches, and serves synced lyrics from LRCLIB.
@Observable
final class LyricsProvider {
    private(set) var lines: [LyricLine] = []
    private(set) var hasLyrics = false
    private(set) var isLoading = false

    private static let fileManager = FileManager.default
    private static let baseURL = "https://lrclib.net/api"

    // MARK: - Lookup

    /// Binary search for the current lyric line at the given time.
    func currentLine(at time: Double) -> LyricLine? {
        guard !lines.isEmpty else { return nil }

        var low = 0
        var high = lines.count - 1
        var result: Int?

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= time {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        guard let index = result else { return nil }
        return lines[index]
    }

    /// The lyric line after the current one.
    func nextLine(at time: Double) -> LyricLine? {
        guard let current = currentLine(at: time) else {
            return lines.first
        }
        guard let index = lines.firstIndex(where: { $0.time == current.time }),
              index + 1 < lines.count else {
            return nil
        }
        return lines[index + 1]
    }

    /// The lyric line before the current one.
    func previousLine(at time: Double) -> LyricLine? {
        guard let current = currentLine(at: time),
              let index = lines.firstIndex(where: { $0.time == current.time }),
              index > 0 else {
            return nil
        }
        return lines[index - 1]
    }

    // MARK: - Fetch & Cache

    /// Load lyrics from cache or fetch from LRCLIB.
    @MainActor
    func fetch(
        title: String,
        artist: String?,
        duration: Int,
        songId: String
    ) async {
        if loadCached(songId: songId) { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let lrc = try await fetchFromAPI(
                title: title,
                artist: artist,
                duration: duration
            )
            saveToDisk(lrc: lrc, songId: songId)
            lines = LRCParser.parse(lrc)
            hasLyrics = !lines.isEmpty
                let count = lines.count
            AppLogger.lyrics.info(
                "Loaded \(count) lyric lines for \(songId)"
            )
        } catch {
            AppLogger.lyrics.warning(
                "Lyrics fetch failed for \(songId): \(error.localizedDescription)"
            )
        }
    }

    /// Try loading cached LRC file. Returns true if successful.
    @discardableResult
    func loadCached(songId: String) -> Bool {
        let url = Self.cacheURL(for: songId)
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return false
        }
        lines = LRCParser.parse(content)
        hasLyrics = !lines.isEmpty
        if hasLyrics {
            AppLogger.lyrics.debug("Lyrics cache hit for \(songId)")
        }
        return hasLyrics
    }
}

// MARK: - Private

private extension LyricsProvider {
    static func cacheURL(for songId: String) -> URL {
        let caches = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        return caches
            .appendingPathComponent("lyrics", isDirectory: true)
            .appendingPathComponent("\(songId).lrc")
    }

    func saveToDisk(lrc: String, songId: String) {
        let url = Self.cacheURL(for: songId)
        let directory = url.deletingLastPathComponent()
        try? Self.fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try? lrc.write(to: url, atomically: true, encoding: .utf8)
    }

    func fetchFromAPI(
        title: String,
        artist: String?,
        duration: Int
    ) async throws -> String {
        // Try exact match first
        if let artist, !artist.isEmpty {
            if let lrc = try? await fetchExact(
                title: title,
                artist: artist,
                duration: duration
            ) {
                return lrc
            }
        }

        // Fall back to search
        return try await fetchSearch(title: title, artist: artist)
    }

    func fetchExact(
        title: String,
        artist: String,
        duration: Int
    ) async throws -> String {
        var components = URLComponents(string: "\(Self.baseURL)/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(duration)),
        ]

        guard let url = components.url else {
            throw LyricsError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LyricsError.notFound
        }

        let result = try JSONDecoder().decode(LRCLibResult.self, from: data)
        guard let syncedLyrics = result.syncedLyrics, !syncedLyrics.isEmpty else {
            throw LyricsError.noSyncedLyrics
        }

        return syncedLyrics
    }

    func fetchSearch(title: String, artist: String?) async throws -> String {
        let query = [title, artist].compactMap { $0 }.joined(separator: " ")
        var components = URLComponents(string: "\(Self.baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
        ]

        guard let url = components.url else {
            throw LyricsError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LyricsError.notFound
        }

        let results = try JSONDecoder().decode([LRCLibResult].self, from: data)
        guard let match = results.first(where: { $0.syncedLyrics != nil }),
              let syncedLyrics = match.syncedLyrics else {
            throw LyricsError.noSyncedLyrics
        }

        return syncedLyrics
    }
}

// MARK: - Models

private struct LRCLibResult: Decodable {
    let syncedLyrics: String?
    let trackName: String
    let artistName: String
    let duration: Double
}

enum LyricsError: Error {
    case invalidURL
    case notFound
    case noSyncedLyrics
}
