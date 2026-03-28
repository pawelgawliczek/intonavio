import Foundation

extension PracticeViewModel {
    /// Load lyrics from cache or fetch from LRCLIB for the current song.
    func fetchLyricsIfNeeded(title: String, artist: String?, duration: Int) {
        Task { @MainActor in
            await lyricsProvider.fetch(
                title: title,
                artist: artist,
                duration: duration,
                songId: songId
            )
        }
    }
}
