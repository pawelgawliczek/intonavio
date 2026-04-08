import Foundation

/// On-disk cache for merged reference pitch data produced by applying a
/// `PitchEditScript` to a base variant. Keyed by `<songId>-<updatedAtEpochMs>.json`
/// so that any script change naturally invalidates stale entries.
enum MergedFrameCache {
    private static let directoryName = "pitch-merged"
    private static let fileManager = FileManager.default

    private static func rootURL() -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private static func stamp(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    }

    private static func fileURL(songId: String, updatedAt: Date) -> URL {
        rootURL().appendingPathComponent("\(songId)-\(stamp(updatedAt)).json")
    }

    static func load(songId: String, updatedAt: Date) -> ReferencePitchData? {
        let url = fileURL(songId: songId, updatedAt: updatedAt)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ReferencePitchData.self, from: data)
        } catch {
            AppLogger.pitch.error(
                "MergedFrameCache: load failed for \(songId): \(error.localizedDescription)"
            )
            return nil
        }
    }

    static func save(songId: String, updatedAt: Date, data: ReferencePitchData) {
        let url = fileURL(songId: songId, updatedAt: updatedAt)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            AppLogger.pitch.error(
                "MergedFrameCache: save failed for \(songId): \(error.localizedDescription)"
            )
        }
    }

    /// Delete every cache entry for `songId` whose stamp differs from `keepUpdatedAt`.
    /// Pass `nil` for `keepUpdatedAt` to delete all entries for the song.
    static func invalidate(songId: String, keepUpdatedAt: Date? = nil) {
        let keepStamp = keepUpdatedAt.map { stamp($0) }
        let prefix = "\(songId)-"
        guard let entries = try? fileManager.contentsOfDirectory(
            at: rootURL(),
            includingPropertiesForKeys: nil
        ) else { return }
        for entry in entries where entry.pathExtension == "json" {
            let name = entry.deletingPathExtension().lastPathComponent
            guard name.hasPrefix(prefix) else { continue }
            let tail = String(name.dropFirst(prefix.count))
            if let keepStamp, Int64(tail) == keepStamp { continue }
            try? fileManager.removeItem(at: entry)
        }
    }
}
