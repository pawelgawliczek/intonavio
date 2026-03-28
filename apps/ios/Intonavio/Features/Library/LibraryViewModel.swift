import Foundation

/// Manages the user's song library: fetching, adding, polling.
@Observable
final class LibraryViewModel {
    var songs: [SongResponse] = []
    var isLoading = false
    var isAddingSong = false
    var errorMessage: String?
    var showAddSheet = false
    var addSongURL = ""
    var addSongError: String?

    private let apiClient: any APIClientProtocol
    private var pollingTask: Task<Void, Never>?
    private let network = NetworkMonitor.shared

    init(apiClient: any APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
        loadSongsFromCache()
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Fetch Songs

    func fetchSongs() {
        guard !isLoading else { return }
        Task { @MainActor in
            await loadSongs()
        }
    }

    @MainActor
    func loadSongs() async {
        let hasCachedSongs = !songs.isEmpty
        isLoading = !hasCachedSongs
        errorMessage = nil

        if network.isConnected {
            do {
                let response = try await apiClient.listSongs(page: 1, limit: 100)
                songs = response.data
                persistSongsToCache()
                startPollingIfNeeded()
                cacheMissingPitchData()
            } catch {
                loadSongsFromCache()
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
                AppLogger.library.error("Failed to load songs: \(error.localizedDescription)")
            }
        } else {
            loadSongsFromCache()
        }

        isLoading = false
    }

    // MARK: - Add Song

    func addSong() {
        guard validateURL() else { return }
        Task { @MainActor in
            await performAddSong()
        }
    }

    // MARK: - Refresh Single Song

    @MainActor
    func refreshSong(id: String) async {
        do {
            let previous = songs.first { $0.id == id }
            let updated = try await apiClient.getSong(id: id)
            if let index = songs.firstIndex(where: { $0.id == id }) {
                songs[index] = updated
            }

            let justBecameReady = previous?.status.isProcessing == true
                && updated.status == .ready
            if justBecameReady, updated.pitchData != nil {
                downloadPitchData(songId: id)
            }
        } catch {
            AppLogger.library.error("Failed to refresh song \(id): \(error.localizedDescription)")
        }
    }

    private func downloadPitchData(songId: String) {
        guard !PitchDataDownloader.isCached(songId: songId) else { return }
        Task {
            do {
                _ = try await PitchDataDownloader.localURL(
                    songId: songId,
                    apiClient: apiClient
                )
            } catch {
                AppLogger.library.error(
                    "Failed to download pitch data for \(songId): \(error.localizedDescription)"
                )
            }
        }
    }

    /// Download pitch data for all READY songs that have it but aren't cached yet.
    /// Runs in the background after loading the song list.
    private func cacheMissingPitchData() {
        let needsDownload = songs.filter { song in
            song.status == .ready
                && song.pitchData != nil
                && !PitchDataDownloader.isCached(songId: song.id)
        }

        for song in needsDownload {
            downloadPitchData(songId: song.id)
        }

        if !needsDownload.isEmpty {
            let count = needsDownload.count
            AppLogger.library.info("Downloading pitch data for \(count) songs")
        }
    }
}

// MARK: - Private

private extension LibraryViewModel {
    @MainActor
    func performAddSong() async {
        isAddingSong = true
        addSongError = nil

        do {
            let response = try await apiClient.createSong(
                CreateSongRequest(youtubeUrl: addSongURL)
            )

            if let index = songs.firstIndex(where: { $0.id == response.id }) {
                songs[index] = response
            } else {
                songs.insert(response, at: 0)
            }

            addSongURL = ""
            showAddSheet = false
            startPollingIfNeeded()
            AppLogger.library.info("Song added: \(response.id)")
        } catch {
            addSongError = (error as? APIError)?.message ?? error.localizedDescription
            AppLogger.library.error("Failed to add song: \(error.localizedDescription)")
        }

        isAddingSong = false
    }

    func validateURL() -> Bool {
        guard !addSongURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            addSongError = "Please enter a YouTube URL"
            return false
        }
        guard YouTubeURLValidator.isValid(addSongURL) else {
            addSongError = "Invalid YouTube URL"
            return false
        }
        return true
    }

    // MARK: - Library Cache

    static let libraryCacheURL: URL = {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        return caches
            .appendingPathComponent("library", isDirectory: true)
            .appendingPathComponent("songs.json")
    }()

    func persistSongsToCache() {
        do {
            let dir = Self.libraryCacheURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(songs)
            try data.write(to: Self.libraryCacheURL)
        } catch {
            AppLogger.library.error(
                "Failed to cache song library: \(error.localizedDescription)"
            )
        }
    }

    func loadSongsFromCache() {
        guard let data = try? Data(contentsOf: Self.libraryCacheURL),
              let cached = try? JSONDecoder().decode(
                  [SongResponse].self, from: data
              )
        else { return }
        songs = cached
        AppLogger.library.info("Loaded \(cached.count) songs from cache")
    }

    // MARK: - Polling

    func startPollingIfNeeded() {
        let hasProcessing = songs.contains { $0.status.isProcessing }
        guard hasProcessing else {
            pollingTask?.cancel()
            pollingTask = nil
            return
        }

        guard pollingTask == nil else { return }

        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, let self else { break }

                let processingIds = self.songs
                    .filter { $0.status.isProcessing }
                    .map(\.id)

                guard !processingIds.isEmpty else { break }

                for id in processingIds {
                    await self.refreshSong(id: id)
                }

                let stillProcessing = self.songs.contains { $0.status.isProcessing }
                if !stillProcessing { break }
            }

            self?.pollingTask = nil
        }
    }
}
