import Foundation

struct BestTakeMetadata: Codable {
    let startOffset: TimeInterval
    let score: Double
    let date: Date
    /// Combined I/O latency at recording time (Bluetooth + Voice Processing).
    /// Used to trim the vocal start during playback so it aligns with the instrumental.
    var ioLatency: TimeInterval = 0
    /// User-adjustable sync offset (seconds) to fine-tune vocal alignment.
    /// Positive values skip more vocal frames (vocal was late).
    var syncOffset: TimeInterval = 0

    /// Total vocal skip = ioLatency + user sync adjustment.
    var totalVocalSkip: TimeInterval { ioLatency + syncOffset }
}

/// File management for best take recordings stored in Documents/best-takes/.
enum BestTakeStorage {
    private static var baseDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("best-takes", isDirectory: true)
    }

    static func audioURL(for songId: String) -> URL {
        baseDir.appendingPathComponent("\(songId).caf")
    }

    static func metadataURL(for songId: String) -> URL {
        baseDir.appendingPathComponent("\(songId).json")
    }

    static func exists(for songId: String) -> Bool {
        FileManager.default.fileExists(atPath: audioURL(for: songId).path)
    }

    /// Atomically move a temp recording to the best-take location and write metadata.
    static func promote(
        tempURL: URL,
        songId: String,
        metadata: BestTakeMetadata
    ) throws {
        let dir = baseDir
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        let destAudio = audioURL(for: songId)

        // Atomic replace (handles existing file)
        if FileManager.default.fileExists(atPath: destAudio.path) {
            _ = try FileManager.default.replaceItemAt(destAudio, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: destAudio)
        }

        // Write metadata sidecar
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL(for: songId), options: .atomic)

        AppLogger.recording.info(
            "Best take promoted for song \(songId) — score: \(metadata.score)"
        )
    }

    static func loadMetadata(songId: String) -> BestTakeMetadata? {
        let url = metadataURL(for: songId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BestTakeMetadata.self, from: data)
    }

    static func delete(for songId: String) {
        try? FileManager.default.removeItem(at: audioURL(for: songId))
        try? FileManager.default.removeItem(at: metadataURL(for: songId))
        AppLogger.recording.info("Best take deleted for song \(songId)")
    }

    /// Update just the sync offset in existing metadata.
    static func updateSyncOffset(songId: String, offset: TimeInterval) {
        guard var meta = loadMetadata(songId: songId) else { return }
        meta.syncOffset = offset
        guard let data = try? JSONEncoder().encode(meta) else { return }
        try? data.write(to: metadataURL(for: songId), options: .atomic)
    }

    /// URL for temp recording files (in Caches, auto-cleaned by OS).
    static func tempURL() -> URL {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        return caches.appendingPathComponent("best-take-temp-\(UUID().uuidString).caf")
    }
}
